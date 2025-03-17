**安装linux子系统-详细教程。**

文字版教程，如果你想省事，请直接看简单教程

*（[windows11 安装WSL2全流程_wsl2安装-CSDN博客](https://blog.csdn.net/u011119817/article/details/130745551)，或其他安装WSL2的教程，有一定概率报错，这与每个人的电脑设置有关，试过许多电脑，还没有报错），按照这个来，安装好linux子系统就OK，可以不用安装图形界面。具体*步骤如下

a)       [启用window子系统及虚拟化](https://blog.csdn.net/u011119817/article/details/130745551#1window_14)

**《Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux》**

先别重启！

**《Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform》**

开启完这两个后，电脑需要重启

b)      [下载发行版本](https://aka.ms/wslubuntu2004)

c)
power shell 以管理员方式运行后，输入：

《**wsl --update**》

《**wsl --set-default-version 2**》

d)
双击安装b)中下好的子系统，设置linux系统名字与密码，然后就安好linux子系统。

    注意：输入密码时并不会显示你输入了什么，密码注意别太麻烦，设置一个字符都可以
