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

NOTE: The version of dokan I used works on on older Windows systems (pre Win7), but may not work on newer ones.  
I first tried using dokany, but it blocks installation on older Windows systems.  

However, it shouldn't be too hard to get it to work using the newer DLLs as well.  In fact, you can try installing the version that works for you, update dokan.dll, and see it it works.
