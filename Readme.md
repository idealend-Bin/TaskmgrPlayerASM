# TaskmgrPlayerASM

![GitHub��ԭ��Ŀ�Ŀ��ܵĽ�ͼ��������еĻ����Է�һ��](��ѡ��ͼƬ����)

����������������ܱ�ǩҳ�в�����Ƶ�������߼�ʹ�� x64 �����д��

## ��Ŀ��� (Project Description)

TaskmgrPlayerASM ��һ������ [svr2kos2/TaskmgrPlayer](https://github.com/svr2kos2/TaskmgrPlayer) ��Ŀ��������Ʒ��ԭ��Ŀʵ���� Windows ��������������ܱ�ǩҳ����ʾ��Ƶ��

**TaskmgrPlayerASM ����Ҫ�ص����ڣ����ǽ�ԭ��Ŀ�еĺ����߼�������Ҵ��ڡ�ö���Ӵ��ڡ������жϡ�������Ϣ��������������̿��ƣ��󲿷ֶ���ֲ��ʹ��ԭ���� x64 ������ԣ�MASM����������дʵ��**���������������� OpenCV C++ API �Ĳ��֣���ͼ������Ƶ��ȡ��������ʾ����

�����Ŀּ��̽����������� Windows ƽ̨�µ�Ӧ�ã����Ͳ㼶ϵͳ�����͵���Լ�� (x64 ABI)�����Ա���߼�����ʵ�ֵĲ��졣

## �������� (Features)

* �� Windows ��������������ܱ�ǩҳ����Ƕ��������Ƶ��
* ���Ĵ��ڲ��ҡ��жϺ������̿����߼��� x64 ���ʵ�֡�
* ���� OpenCV ������Ƶ���롢ͼ���� (��ֵ��, ��Ե���) �ʹ�����ʾ��
* ֧�ֲ���ָ����Ƶ�ļ� (�� BadApple.flv)��
* ��������������ù��ܣ�֧��ͨ�������ļ� (`config.cfg`) �Զ�����ʾ��ɫ������

## ���� (Building)

����Ŀ��Ҫ MASM (ml64.exe) ��֧�� C++11 ����߱�׼�� C++ ������ (�� Visual Studio �� MSVC)��

1.  **��¡�ֿ⣺**
    ```cmd
    git clone [https://github.com/YourGitHubUsername/TaskmgrPlayerASM.git](https://github.com/YourGitHubUsername/TaskmgrPlayerASM.git)
    cd TaskmgrPlayerASM
    ```
    (������Ǵ�����һ���µĶ����ֿ⣬���һ�û���ϴ�����ô�ⲽ�Ǹ�δ�����û����ġ������ GitHub fork�����ӻ������ fork ��ַ)

2.  **׼�� OpenCV��**
    * ���ز���װ OpenCV �⡣
    * ������ı��뻷����ȷ�� C++ ���������ҵ� OpenCV ��ͷ�ļ� (`include` Ŀ¼) �Ϳ��ļ� (`lib` Ŀ¼)��

3.  **�������ļ���**
    * ʹ�� `ml64.exe` �������е� `.asm` �ļ��� `.obj` �ļ���
    * ʾ������ (�ڿ�����������ʾ����):
        ```cmd
        ml64.exe /c /Fo EnumChildWindowProc.obj EnumChildWindowProc.asm
        ml64.exe /c /Fo FindWnd.obj FindWnd.asm
        ml64.exe /c /Fo IsSmallerWindow.obj IsSmallerWindow.asm
        ml64.exe /c /Fo main.obj main.asm
        ml64.exe /c /Fo OutPutDbg.obj OutPutDbg.asm
        ml64.exe /c /Fo Play.obj Play.asm
        ```

4.  **���� C++ �ļ���**
    * ʹ�� C++ ������������� `TaskmgrPlayer.cpp` �ļ��� `.obj` �ļ���
    * ʾ������ (��Ҫ��ȷ���ð���Ŀ¼���ҵ� OpenCV ͷ�ļ�):
        ```cmd
        cl.exe /c /Fo TaskmgrPlayer.obj TaskmgrPlayer.cpp /I "path/to/opencv/include" /std:c++17 /EHsc
        ```
        (ע�� `/std:c++17` �� `/std:c++14` ��ȡ������Ĵ����Ƿ�ʹ���� C++11 �������ԣ�`/EHsc` �����쳣����)

5.  **���ӣ�**
    * �����е� `.obj` �ļ����ӳ�һ����ִ���ļ� (`TaskmgrPlayerASM.exe`)������Ҫ���� Windows API �� (User32.lib, Kernel32.lib, Gdi32.lib, Advapi32.lib, Winmm.lib) �� OpenCV �Ŀ⡣
    * ʾ������ (��Ҫ��ȷ���ÿ�Ŀ¼���ҵ� Windows SDK ��� OpenCV ��):
        ```cmd
        link.exe EnumChildWindowProc.obj FindWnd.obj IsSmallerWindow.obj main.obj OutPutDbg.obj Play.obj TaskmgrPlayer.obj user32.lib kernel32.lib gdi32.lib advapi32.lib winmm.lib "path/to/opencv/lib/opencv_world<version>.lib" /OUT:TaskmgrPlayerASM.exe
        ```
        (�뽫 `<version>` �滻Ϊ��ʹ�õ� OpenCV �汾��)

## ���� (Running)

1.  ���������ɵ� `TaskmgrPlayerASM.exe` ��ִ���ļ�������� OpenCV DLL �ļ��Լ�����Ҫ���ŵ���Ƶ�ļ� (���� `BadApple.flv`) ����ͬһ��Ŀ¼�¡�
2.  ���� `TaskmgrPlayerASM.exe`��
3.  �� Windows ��������������л��������ܡ���ǩҳ������Ӧ�û��Զ��ҵ�������������ڲ���������ʾ��Ƶ��
4.  ��������������ù��ܣ��������ͬһĿ¼�·���һ�� `config.cfg` �ļ���������ʾ���á�


```
���Э�� (License)
����Ŀ��ѭ GNU General Public License v3.0 ���Э�顣������μ���Ŀ��Ŀ¼�µ� https://www.google.com/search?q=LICENSE �ļ���

����Ŀ�ǻ��� svr2kos2/TaskmgrPlayer (GPL-3.0 Э��) ��������Ʒ��

���� (Contributing)
��ӭ�Ա���Ŀ���������״��롣��ͨ�� GitHub �� Issue �� Pull Request ���ܽ��н�����

��л (Acknowledgements)
����Ŀ���� svr2kos2 �� TaskmgrPlayer ԭ��Ŀ���ǳ���лԭ���ߵĴ���ͳ���ʵ�֡�

��л��������Ŀ�����������ṩ�����ͽ�������ѡ�

���� (Author)
Idealend Bin - [��� GitHub ��ҳ���ӻ�������ϵ��ʽ]