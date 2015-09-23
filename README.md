# dipfs
mount the [ipfs distributed file system](https://github.com/ipfs/go-ipfs) to a Windows drive via dokan

basic read-only interface between ipfs and dokan, works by connecting to the local ipfs REST endpoint at http://127.0.0.1:5001/api/ 
to mount the ipfs distributed file system to a Windows drive via dokan (like Fuse for Linux).

The code is in Delphi 7, and should be relatively easily adaptable to FreePascal or later version of Delphi.

usage (*make sure ipfs is already running via "ipfs daemon"*):

```
dipfs /l z       <-- will link \ipfs\ and \ipns\ to drive z:
dipfs /l z /d    <-- same as above, with additional output for debugging
```

from Windows Command Prompt, try the following:

```
z: 
cd \ipfs\QmPXME1oRtoT627YKaDPDQ3PwA8tdP9rWuAAweLzqSwAWT
dir
type readme
```

for a node with a subdirectory structure, try the following:

``` 
cd \ipfs\QmRCJXG7HSmprrYwDrK1GctXHgbV7EYpVcJPQPwevoQuqF
```

Additional Source Code Dependencies: HTTPSend (Synapse)

See releases for a compiled version.  

Required Driver/DLL Install File:

* For new versions of Windows (Windows 10, Windows 8.1, Windows Server 2012 R2, Windows 8, Windows Server 2012, Windows 7) use latest dokany release: https://github.com/dokan-dev/dokany/releases

* for 32-bit/64-bit Windows 7 or below, you can use the version of dokan under releases: **DokanInstall_0.6.0.exe**
