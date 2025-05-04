// TaskmgrPlayerASM - Derived from svr2kos2/TaskmgrPlayer (https://github.com/svr2kos2/TaskmgrPlayer)
//
// Copyright (c) [Original project creation year(s), if known] [Original Author Name(s), e.g., svr2kos2]
// Copyright (c) 2025 Idealend Bin // Copyright for modifications and new code integrated into this file
//
// This file is part of TaskmgrPlayerASM.
// TaskmgrPlayerASM is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// TaskmgrPlayerASM is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with TaskmgrPlayerASM. If not, see <https://www.gnu.org/licenses/>.
//
//------------------------------------------------------------------------------
// Modifications by Idealend Bin on 2025-05-04:
// - Rewrote pixel access method in Binarylize function (using Mat::ptr for efficiency).
// - Rewrote error handling logic in PlayLoop function (added robust size checks and handling invalid window sizes).
// - Integrated calls to assembly functions for core logic (FindWnd, Play, OutPutDbg etc.), replacing original C++ implementations.
// - Updated global variable usage to be C-compatible for assembly interaction where necessary.
// - Added standard GPL header and modification notices.
// - Other minor code cleanup and adjustments for integration.
//------------------------------------------------------------------------------


#ifndef UNICODE
#define UNICODE
#endif // UNICODE

#include <Windows.h> // 包含 WinAPI 函数、HWND, RECT 等，通常也包含了 lstrcpyW 和 lstrcmpW

#include <opencv2/opencv.hpp> // 包含 OpenCV 的核心功能，推荐使用 opencv2/... 风格的头文件路径

#pragma comment(lib, "winmm.lib") // Link winmm.lib for PlaySoundW
#pragma comment(lib, "User32.lib") // Link User32.lib for window management functions
#pragma comment(lib, "Kernel32.lib") // Link Kernel32.lib for console functions
// 可能还需要其他库，具体取决于使用的 WinAPI 函数，例如 Gdi32.lib, Advapi32.lib 等


using namespace cv; // 保留 using namespace cv;

// Global constants - const wchar_t[] are C-compatible data
// These variables are defined in one of the assembly files and accessed here.
extern "C" {
	extern const wchar_t WindowClassName[] = L"TaskManagerWindow"; // Task Manager window class name
	extern const wchar_t WindowTitle[] = L"任务管理器";     // Task Manager window title
	extern wchar_t ChildClassName[] = L"CvChartWindow"; // Specific child window class name to find within Task Manager

	// OpenCV drawing colors (Vec3b is an OpenCV type, defined in ASM .data)
	extern Vec3b colorEdge = { 187, 125, 12 };
	extern Vec3b colorDark = { 250, 246, 241 };
	extern Vec3b colorBright = { 255, 255, 255 };
	extern Vec3b colorGrid = { 244, 234, 217 };
	extern Vec3b colorFrame = { 187, 125, 12 };

	extern bool DrawGrid = true; // Flag to control drawing grid
	extern int Conuter = 0; // Simple counter (Purpose might need clarification)

	volatile extern HWND EnumHWnd = 0; // Handle to the found target window (Task Manager or its child)

	// Buffer to store the class name to enumerate (used by EnumChildWindowsProc)
	extern wchar_t ClassNameToEnum[256]{};
}

// --- External Assembly/C-compatible Function Declarations ---
// These functions are implemented in assembly files and called from the C++ PlayLoop.
// Note: FindWnd, EnumChildWindowsProc, Play are now fully in ASM and not called directly from *this* C++ file anymore.
extern "C" BOOL IsSmallerWindowLogic(HWND hWnd); // Implemented in IsSmallerWindow.asm - Used by EnumChildWindowsProc (in ASM)

extern "C" void OutPutDbg(int* frameCount, double frameTime, int w, int h, clock_t s); // Implemented in OutPutDbg.asm

// Wrapper for OpenCV's namedWindow() - Called by Play (in ASM)
extern "C" void NamedWindow(const char* name, int flags)
{
	namedWindow(name, flags); // Call OpenCV C++ function namedWindow, which accepts const char*
}

// Wrapper for OpenCV's waitKey() - Called by OutPutDbg (in ASM)
extern "C" int WaitKey(int delay) 
{
	return waitKey(delay); // Call OpenCV C++ function waitKey, which returns int
}
// --- C++ Functions Retained (Due to Extensive OpenCV C++ API Usage) ---

// Binarylize function - Processes a frame (modified to use ptr access)
extern "C" void Binarylize(Mat& src)
{
	Mat bin, edge; // cv::Mat is an OpenCV C++ type
	cvtColor(src, bin, COLOR_BGR2GRAY); // OpenCV C++ function
	inRange(bin, Scalar(128, 128, 128), Scalar(255, 255, 255), bin); // OpenCV C++ function，Scalar is a C++ type

	Canny(bin, edge, 80, 130); // OpenCV C++ function

	// src.cols/rows are C++ methods, returning int. Calculations are C-compatible.
	int gridHeight = (int)(src.cols / 10.0); // Explicit cast to int
	int gridWidth = (int)(src.rows / 8.0); // Explicit cast to int
	// clock() is a CRT function, returns clock_t. Calculation is C-compatible.
	// Note: This grid offset calculation is based on system clock, might drift relative to video frames.
	int gridOffset = (int)((double)clock() / 1000.0 * 10.0); // Ensure double precision calculation before converting to int

	// Loop structure is C-compatible
	// Using pointer optimization for pixel access (Implemented by Idealend Bin)
	for (int r = 0; r < src.rows; ++r)
	{
		// Get pointer to the current row
		Vec3b* src_row_ptr = src.ptr<Vec3b>(r);
		uchar* bin_row_ptr = bin.ptr<uchar>(r);
		uchar* edge_row_ptr = edge.ptr<uchar>(r);

		for (int c = 0; c < src.cols; ++c)
		{
			// Direct pixel access via pointer
			src_row_ptr[c] = ((bin_row_ptr[c] == 255) ? colorBright : colorDark);
			if(DrawGrid)
				if (r % gridHeight == 0 || (c + gridOffset) % gridWidth == 0) src_row_ptr[c] = colorGrid;
			if (edge_row_ptr[c] == 255) src_row_ptr[c] = colorEdge;
		}
	}
	// rectangle uses Rect and Scalar (OpenCV C++ types)
	// Note: thickness 0.1 is unusual, typically integer thickness. 0 means no border. Maybe intended 1?
	rectangle(src, Rect{ 0,0,src.cols,src.rows }, colorFrame, 0.1); // OpenCV C++ function, uses C++ types
}



// Main loop for video playback and window updates - Called by Play (in ASM)
extern "C" void PlayLoop(const char* videoName, const char* wndName, int* frameCount, HWND playerWnd, RECT rect)
{
	// Note: videoName, wndName, frameCount*, playerWnd, rect are passed from Play.asm
	VideoCapture video(videoName); // VideoCapture is an OpenCV C++ class

	if (!video.isOpened()) // Check if video file opened successfully (Error handling logic rewritten by Idealend Bin)
	{
		wprintf(L"Error: Could not open video file %hs\n", videoName); // Use %hs for char* in wprintf for consistent wide output
		// The loop condition 'video.read(frame)' will be false if not opened, so loop will be skipped.
		// No need for 'return' here.
	}

	// Calculate frame time based on video FPS. Calculation is C-compatible.
	double frameTime = 1000.0 / video.get(CAP_PROP_FPS);

	// Loop through video frames
	// Loop structure is C-compatible (for loop with initialization, condition, and increment)
	// video.read(frame) reads the next frame into 'frame' Mat. Returns true on success.
	for (Mat frame; video.read(frame); (*frameCount)++)
	{
		clock_t s = clock(); // Get current time using CRT function

		// Get parent window's dimensions and update player window position/size
		GetWindowRect(EnumHWnd, &rect); // Get parent window's dimensions into the rect variable (passed by value, but modified here)
		int w = rect.right - rect.left; // Calculate width from rect
		int h = rect.bottom - rect.top; // Calculate height from rect
		MoveWindow(playerWnd, 0, 0, w, h, TRUE); // Resize/reposition the player window (child) to fit the parent

		// Process and display the frame only if the target window size is valid (Error handling logic rewritten by Idealend Bin)
		if (w > 0 && h > 0)
		{
			// Resize the frame to the window dimensions
			// Note: Using resize(frame, frame, ...) performs in-place resize.
			resize(frame, frame, cv::Size(w, h), 0, 0, INTER_NEAREST); // Resize the frame to window dimensions

			// Apply Binarylize processing to the resized frame
			Binarylize(frame); // Process the frame (now resized)

			// Display the processed frame in the named window
			imshow(wndName, frame); // Display the frame (now processed and resized)
		}
		else
		{
			// If window size is invalid, skip processing and display for this frame
			wprintf(L"Window size is invalid or zero: %d, %d. Skipping frame processing.\n", w, h); // Use wprintf for wide string literal
		}

		// Output debug information to the console
		OutPutDbg(frameCount, frameTime, w, h, s); // Call OutPutDbg function (Implemented in ASM)

		// The while loop for timing is now handled inside OutPutDbg (in ASM)
		// The waitKey call for pacing is also inside OutPutDbg (in ASM)
	}

	// After the loop, destroy the OpenCV window
	destroyWindow(wndName);
	// Optional: release the video capture object
	// video.release(); // VideoCapture destructor will handle this automatically
}

// Play function is now fully implemented in Play.asm and orchestrates the main flow.
// It is called by main (in main.asm) and calls PlayLoop (in this file).
// extern "C" void Play(); // Declared extern in main.asm, implemented in Play.asm


// The original C++ Play and main functions are commented out as they are replaced by assembly implementations.
/*
extern "C" void Play() { ... }
int main() { ... }
*/