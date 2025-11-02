# FuelRods

我的中文版零基础moose教程，热力耦合的燃料芯块模拟。

# 第一章，安装

## 第一步：安装WSL

（用终端脚本下载步骤b)的文件太慢了，这里没有做脚本）
一开始没有安装window的子系统linux（WSL）前，先不需要将全部代码clone下来，只需要看着下面教程一步步来即可，**前往别想着跳步！前往别想着跳步！前往别想着跳步！**

*（[windows11 安装WSL2全流程_wsl2安装-CSDN博客](https://blog.csdn.net/u011119817/article/details/130745551)，或其他安装WSL2的教程，有一定概率报错，这与每个人的电脑设置有关，试过许多电脑，还没有报错），按照这个来，安装好linux子系统就OK，可以不用安装图形界面。具体*步骤如下

a)       [启用window子系统及虚拟化](https://blog.csdn.net/u011119817/article/details/130745551#1window_14)

    windows终端power shell输入：

    **《Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux》**

    先别重启！

    **《Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform》**

    开启完这两个后，电脑需要重启

b)      [下载发行版本]不能跳过！！！(https://aka.ms/wslubuntu2004)

c)      [更新WSL2前置]
    windows终端power shell输入：

    《**wsl --update**》

    《**wsl --set-default-version 2**》

d)      [安装linux子系统]
    双击安装b)中下好的子系统，设置linux系统名字与密码，然后就安好linux子系统。

    注意：输入密码时并不会显示你输入了什么，密码注意别太麻烦，设置一个字符都可以

## 第二步：安装Cursor

直接去官网安装最新版的Cursor，这在以后得代码编辑中中讲大放异彩

[Cursor - The AI Code Editor](https://www.cursor.com/cn)

如何使用Cursor打开子系统WSL？

1，打开任意一个文件夹，在左边选择中下载这么一个插件wsl

![1742203175110](image/README/1742203175110.png)

2。然后安装好后，按顺序同时按住shift+ctrl+p键呼出命令面板，输入wsl，选择连接到wsl，

![1742203291188](image/README/1742203291188.png)

3。并在左侧选择/home/xx/即可，如下图所示

![1742203305450](image/README/1742203305450.png)

到此，linux系统与相关配套的cursor安装好了！！！

## 第三步：安装MOOSE环境

接下来安装相应的conda环境，在左端右键任意一个文件，选择在集成终端打开，出现3号红色矩形的内容，这个

**《在集成终端打开》功能是非常非常非常好用的功能，请务必记住**

![1742203568705](image/README/1742203568705.png)

    确定和我在同一个路径后，将fuel_rods/tutorial/scripts下的几个脚本（这个脚本目前应该在Windows文件夹下）放到子系统的/home/yp文件夹下（yp是我的linux系统名字,你的可能不是），
    具体操作分3步，找到子系统的/home/yp文件夹（下图就是打开的方法），然后找到脚本将其黏贴至/home/yp文件夹即可

![1742206163642](image/README/1742206163642.png)![1742206494662](image/README/1742206494662.png)

    脚本到位后，就变得简单起来

    在cursor显示的终端：

![1742206569067](image/README/1742206569067.png)

    运行如下代码即可：
赋予step1_install_moose_env.sh运行权限：

chmod +x step1_install_moose_env.sh

运行step1_install_moose_env.sh脚本：

./step1_install_moose_env.sh

## 第四步：安装MOOSE本体

在cursor显示的终端：

![1742206569067](image/README/1742206569067.png)

在/home/yp文件夹下运行如下代码即可

赋予step2_install_moose_software.sh运行权限：

chmod +x step2_install_moose_software.sh

运行step1_install_moose_env.sh脚本：

./step2_install_moose_software.sh

耐心等一段时间，看到

![1742208907135](image/README/1742208907135.png)

的类似的结果就可以放心了，这下moose就完全安装好了，没安好就把moose整个文件夹删掉，然后重复该脚本

# 接下来的MOOSE具体教程请看fuel_rods/MOOSE零基础总教程/MOOSE基础知识-整体xxx.docx
