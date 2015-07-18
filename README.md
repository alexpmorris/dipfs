# dipfs
mount the ipfs distributed file system to a Windows drive via dokan

basic read-only interface between ipfs and dokan, works by connecting to the local ipfs REST endpoint at http://127.0.0.1:5001/api/ 
to mount the ipfs distributed file system to a Windows drive via dokan (like Fuse for Linux).

The code is in Delphi 7, and should be relatively easily adaptable to FreePascal or later version of Delphi.

usage (*make sure ipfs is already running via "ipfs daemon"*):

```
dipfs /l z       <-- will link ipfs to drive z:
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

**I confirmed** that DokanInstall_0.6.0.exe (and dipfs) also work on 64-bit Windows 7, as well as on older Windows 32-bit systems.

**NOTE:** I first tried using [dokany](https://github.com/dokan-dev/dokany), but it blocks installation on older Windows systems.  I tried using dipfs with dokany on 64-bit Windows 7, and it worked too.  **HOWEVER**, dokany seems to BSOD every time I tried to dismount the drive (it also happened with their version of mirror.exe, so it's not a dipfs issue).  I've opened an issue with [dokany](https://github.com/dokan-dev/dokany/issues/31) to see if the problem can be tracked down.
