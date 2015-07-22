program dipfs;

(*******************************************************************************
 *
 * dipfs - basic read-only interface between ipfs and dokan, by Alexander Paul Morris
 *         works by connecting to the local ipfs REST endpoint at http://127.0.0.1:5001/api/
 *         to mount the ipfs distributed file system to a Windows drive (like Fuse for Linux)
 *
 *         Confirmed to work with Windows 32-bit and 64-bit installs.
 *         For Windows 7 to Windows 10, use latest dokany release at https://github.com/dokan-dev/dokany
 *
 *
 * v0.12, 2015-07-22, Added access to \ipns\ paths as well (an ipns path is a mutable pointer to an ipfs path)
 *
 * v0.11, 2015-07-17, Cleaned up a few things, and fixed error if no drive id was provided
 *                    Confirmed that DokanInstall_0.6.0.exe and dipfs also work on a
 *                    64-bit Windows7 system, as well as on older Windows 32-bit setups
 *
 * v0.10, 2015-07-16  Initial release
 *
 *
 * usage:
 *   dipfs /l z       <-- will link \ipfs\ and \ipns\ to drive z:
 *   dipfs /l z /d    <-- same as above, with additional output for debugging
 *
 * from Windows Command Prompt, try the following:
 *
 * z: 
 * cd \ipfs\QmPXME1oRtoT627YKaDPDQ3PwA8tdP9rWuAAweLzqSwAWT
 * dir
 * type readme
 *
 * for a node with a subdirectory structure, try the following:
 * 
 * cd \ipfs\QmRCJXG7HSmprrYwDrK1GctXHgbV7EYpVcJPQPwevoQuqF
 *
 *
 * Additional Source Code Dependencies: HTTPSend (Synapse)
 *
 *
 * Copyright (c) 2007, 2008 Hiroki Asakawa info@dokan-dev.net
 *
 * Delphi translation by Vincent Forman (vincent.forman@gmail.com)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 *******************************************************************************)

{$APPTYPE CONSOLE}

uses
  Windows,
  SysUtils,
  Classes,
  SuperObject, HashMap, FastStrings,
  HTTPSend, //ssl_openssl, ssl_openssl_lib, ZLibExGz,
  Dokan in 'Dokan.pas';

const dipfsVersion = '0.12';

// Not available in Windows.pas
function SetFilePointerEx(hFile: THandle; lDistanceToMove: LARGE_INTEGER; lpNewFilePointer: Pointer; dwMoveMethod: DWORD): BOOL; stdcall; external kernel32;

// Some additional Win32 flags
const
  FILE_READ_DATA                     = $00000001;
  FILE_WRITE_DATA                    = $00000002;
  FILE_APPEND_DATA                   = $00000004;
  FILE_READ_EA                       = $00000008;
  FILE_WRITE_EA                      = $00000010;
  FILE_EXECUTE                       = $00000020;
  FILE_READ_ATTRIBUTES               = $00000080;
  FILE_WRITE_ATTRIBUTES              = $00000100;

  FILE_ATTRIBUTE_ENCRYPTED           = $00000040;
  FILE_ATTRIBUTE_NOT_CONTENT_INDEXED = $00002000;
  FILE_FLAG_OPEN_NO_RECALL           = $00100000;
  FILE_FLAG_OPEN_REPARSE_POINT       = $00200000;

  STATUS_DIRECTORY_NOT_EMPTY         = $C0000101;

  INVALID_SET_FILE_POINTER           = $FFFFFFFF;


var HTFileMap: THashMap;


// Utilities routines, to be defined later
procedure DbgPrint(const Message: string); overload; forward;
procedure DbgPrint(const Format: string; const Args: array of const); overload; forward;



procedure GetUrlHtmlWithComp(UrlS: string; var TmpL: TStringList);
var HTTP: THTTPSend;
    //DeCompStream: TGZDecompressionStream;
    TmpStream: TMemoryStream;
    err: boolean;
begin
  TmpL.Clear;

  HTTP := THTTPSend.Create;
  HTTP.Clear;
  HTTP.Timeout := 2500;
  HTTP.UserAgent := 'Mozilla/5.0 (compatible)';  //Mozilla 4.0 disables many gzips! oy
  HTTP.Headers.Add('Accept-Encoding: gzip');
  HTTP.Protocol := '1.1';
  try
  //if (copy(urls,1,5)='https') then begin
  //  HTTP.Sock.CreateWithSSL(TSSLOpenSSL);
  //  HTTP.Sock.SSLDoConnect;
  // end;
  HTTP.HTTPMethod('GET',urls);
  except end;

  TmpStream := TMemoryStream.Create;
  err := false;
  //HTTP.Document.Seek(0,soFromBeginning);
  //try GZDecompressStream(HTTP.Document,TmpStream); except err := true; end;
  HTTP.Document.Seek(0,soFromBeginning);
  TmpStream.Seek(0,soFromBeginning);
  //if (not err) then TmpL.LoadFromStream(TmpStream) else
    TmpL.LoadFromStream(HTTP.Document);
  TmpStream.Free;
  HTTP.Free;

end;


procedure GetUrlHtmlWithCompAsStream(UrlS: string; var TmpStream: TMemoryStream);
var HTTP: THTTPSend;
    //DeCompStream: TGZDecompressionStream;
    err: boolean;
begin
  TmpStream := nil;

  HTTP := THTTPSend.Create;
  HTTP.Clear;
  HTTP.Timeout := 2500;
  HTTP.UserAgent := 'Mozilla/5.0 (compatible)';  //Mozilla 4.0 disables many gzips! oy
  HTTP.Headers.Add('Accept-Encoding: gzip');
  HTTP.Protocol := '1.1';
  try
  //if (copy(urls,1,5)='https') then begin
  //  HTTP.Sock.CreateWithSSL(TSSLOpenSSL);
  //  HTTP.Sock.SSLDoConnect;
  // end;
  HTTP.HTTPMethod('GET',urls);
  except end;

  TmpStream := TMemoryStream.Create;
  err := false;
  //HTTP.Document.Seek(0,soFromBeginning);
  //try GZDecompressStream(HTTP.Document,TmpStream); except err := true; end;
  HTTP.Document.Seek(0,soFromBeginning);
  TmpStream.Seek(0,soFromBeginning);
  //if (not err) then TmpStream.LoadFromStream(TmpStream) else
    TmpStream.LoadFromStream(HTTP.Document);
  HTTP.Free;

end;


Function MyPos(const Srch,Strg: String): Integer;
Begin
  Result := FastPos(Strg,Srch,Length(Strg),Length(Srch),1);
End;

Function MyPosBack(const Srch,Strg: String): Integer;
Begin
  Result := FastPosBack(Strg,Srch,Length(Strg),Length(Srch),length(Strg));
End;

Function LongHandStrNxt(Strg,Srch,Repl: String): String;
{Finds an occurance and copies off - does not consider new changes in search}
var i: integer;
    DumS: String;
Begin
  i := FastPos(Strg,Srch,Length(Strg),Length(Srch),1);
  DumS := '';
  While (i <> 0) Do Begin
    DumS := DumS + Copy(Strg,1,i-1) + Repl;
    Delete(Strg,1,i+Length(Srch)-1);
    i := FastPos(Strg,Srch,Length(Strg),Length(Srch),1);
   End;
  DumS := DumS + Strg;
  Result := DumS;
End;


// Output the value of a flag by searching amongst an array of value/name pairs
procedure CheckFlag(const Flag: Cardinal;
                    Values: array of Cardinal;
                    Names: array of string);
var
  i:Integer;
begin
  for i:=Low(Values) to High(Values) do
    if Values[i]=Flag then
      DbgPrint('    %s',[Names[i]]);
end;

type
  EDokanMainError = class(Exception)
  public
    constructor Create(DokanErrorCode: Integer);
  end;

constructor EDokanMainError.Create(DokanErrorCode: Integer);
var
  s:string;
begin
  case DokanErrorCode of
    DOKAN_SUCCESS: s := 'Success';
    DOKAN_ERROR: s := 'Generic error';
    DOKAN_DRIVE_LETTER_ERROR: s := 'Bad drive letter';
    DOKAN_DRIVER_INSTALL_ERROR: s := 'Cannot install driver';
    DOKAN_START_ERROR: s := 'Cannot start driver';
    DOKAN_MOUNT_ERROR: s := 'Cannot mount on the specified drive letter';
    DOKAN_MOUNT_POINT_ERROR : s := 'Mount point error';
  else
    s := 'Unknown error';
  end;
  inherited CreateFmt('Dokan Error. Code: %d.'+sLineBreak+'%s',[DokanErrorCode,s]);
end;

// Dokan callbacks
function MirrorCreateFile(FileName: PWideChar;
                          AccessMode, ShareMode, CreationDisposition, FlagsAndAttributes: Cardinal;
                          var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
begin
  result := 0;
end;

function MirrorOpenDirectory(FileName: PWideChar;
                             var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
begin
  result := 0;
end;

function MirrorCreateDirectory(FileName: PWideChar;
                               var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
begin
  result := -1;
end;

function MirrorCleanup(FileName: PWideChar;
                       var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
begin
  result := 0;
end;

function MirrorCloseFile(FileName: PWideChar;
                         var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
  TmpStream: TMemoryStream;
  Data: TObject;
begin
  result := 0;

  FilePath := FileName;
  if (Copy(FilePath,Length(FilePath)-1,2)='\*') then Delete(FilePath,length(FilePath)-1,2);
  FilePath := LongHandStrNxt(FilePath,'\','/');

  if HTFileMap.Find(FilePath,Data) then begin
    DbgPrint('CloseFile: %s', [FilePath]);
    TmpStream := TMemoryStream(Data);
    if (TmpStream.Position >= TmpStream.Size-1) then begin
      TmpStream.Free;
      HTFileMap.Delete(FilePath);
     end;
   end;
end;

function MirrorReadFile(FileName: PWideChar;
                        var Buffer;
                        NumberOfBytesToRead: Cardinal;
                        var NumberOfBytesRead: Cardinal;
                        Offset: Int64;
                        var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
  Opened: Boolean;
  Data: TObject;
  TmpS: string;
  obj: ISuperObject;
  hash: string;
  TmpStream: TMemoryStream;
  i: Integer;
begin
  FilePath := FileName;
  if (Copy(FilePath,Length(FilePath)-1,2)='\*') then Delete(FilePath,length(FilePath)-1,2);
  FilePath := LongHandStrNxt(FilePath,'\','/');

  DbgPrint('ReadFile: %s (Offset: %d, Length: %d)', [FilePath, Offset, NumberOfBytesToRead]);

  if HTFileMap.Find('isDir:'+FilePath,Data) then begin
    result := -1;
    exit;
   end;

  FillChar(Buffer,NumberOfBytesToRead,0);  //clear dokan data buffer

  if HTFileMap.Find(FilePath,Data) then begin
    TmpStream := TMemoryStream(Data);
    TmpStream.Seek(Offset,soFromBeginning);
    if (TmpStream.Size-TmpStream.Position < NumberOfBytesToRead) then
      NumberOfBytesToRead := TmpStream.Size-TmpStream.Position;
    TmpStream.ReadBuffer(Buffer,NumberOfBytesToRead);
    NumberOfBytesRead := NumberOfBytesToRead;
   end else begin
     GetUrlHtmlWithCompAsStream('http://127.0.0.1:5001/api/v0/cat?arg='+FilePath,TmpStream);
     if (TmpStream = nil) then begin
       result := -1;
       exit;
      end;
     TmpStream.Seek(0,soFromBeginning);
     if (TmpStream.Size-TmpStream.Position < NumberOfBytesToRead) then
       NumberOfBytesToRead := TmpStream.Size-TmpStream.Position;
     TmpStream.ReadBuffer(Buffer,NumberOfBytesToRead);
     if (TmpStream.Position < TmpStream.Size-1) then begin
       NumberOfBytesRead := NumberOfBytesToRead;
      end else NumberOfBytesRead := TmpStream.Size;
     HTFileMap.Add(FilePath,Pointer(TmpStream));
    end;

end;

function MirrorWriteFile(FileName: PWideChar;
                         var Buffer;
                         NumberOfBytesToWrite: Cardinal;
                         var NumberOfBytesWritten: Cardinal;
                         Offset: Int64;
                         var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
begin
  result := -1;
end;

function MirrorFlushFileBuffers(FileName: PWideChar;
                                var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
begin
  result := -1;
end;


//this part was tricky and very hacky, because we need to get the fileSize (if we are requesting a file),
//so that dokan knows how many times to call ReadFile() versus its 512 byte buffer
function MirrorGetFileInformation(FileName: PWideChar;
                                  FileInformation: PByHandleFileInformation;
                                  var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
  Opened: Boolean;
  FindData: WIN32_FIND_DATAA;
  FindHandle: THandle;
  i,tmpDate,entries,entries2: integer;
  TmpL: TStringList;
  TmpS,fName,fNameTemp: string;
  obj: ISuperObject;
  arr: TSuperArray;
  hash: string;
  fSize: DWORD;
begin
  FilePath := FileName;
  if (LowerCase(FilePath)='autorun.inf') then begin
    result := -1;
    exit;
   end;

  DbgPrint('GetFileInformation: %s', [FilePath]);

  fSize := 0;
  if (Copy(FilePath,1,6) = '\ipfs\') or (Copy(FilePath,1,6) = '\ipns\') then begin
    if (Copy(FilePath,Length(FilePath)-1,2)='\*') then Delete(FilePath,length(FilePath)-1,2);
    FilePath := LongHandStrNxt(FilePath,'\','/');
    TmpL := TStringList.Create;
    GetUrlHtmlWithComp('http://127.0.0.1:5001/api/v0/ls?arg='+FilePath,TmpL);
    TmpS := TmpL.Text;
    TmpL.Free;
    try
      obj := SO(TmpS);
      hash := obj.a['Objects'].o[0].s['Hash'];
      entries := 0;
      arr := obj.a['Objects'].o[0].o['Links'].AsArray;
      if assigned(arr) then entries := arr.Length;
    except result := -1; exit; end;
    fName := FilePath;
    fNameTemp := '';
    i := MyPosBack('/',fName);
    if (i<>0) then begin
      fNameTemp := lowercase(Copy(fName,i+1,length(fName)));
      delete(fName,i,length(fName));
     end else fName := '';
    entries2 := 0;
    while (entries2 = 0) and (fName <> '') do begin
      //writeln('finding size for: ',fName);
      TmpL := TStringList.Create;
      GetUrlHtmlWithComp('http://127.0.0.1:5001/api/v0/ls?arg='+fName,TmpL);
      TmpS := TmpL.Text;
      TmpL.Free;
      try
        obj := SO(TmpS);
        hash := obj.a['Objects'].o[0].s['Hash'];
        arr := obj.a['Objects'].o[0].o['Links'].AsArray;
        if assigned(arr) then entries2 := arr.Length;
        if (entries2 > 0) then begin
          for i := 0 to entries2-1 do begin
            if (lowercase(arr[i].s['Name']) = fNameTemp) then begin
              if (arr[i].I['Type'] = 1{directory}) then begin
                HTFileMap.Add('isDir:'+FilePath,Pointer(1));
                entries := 1;  //set as a directory later in FileInformation
               end;
              fSize := arr[i].i['Size'];
              //writeln(fName,' gotSize:',fSize,' type:',arr[i].I['Type']);
              break;
             end;
           end;
         end;
      except end;
      i := MyPosBack('/',fName);
      if (i<>0) then begin
        fNameTemp := lowercase(Copy(fName,i+1,length(fName)));
        delete(fName,i,length(fName));
       end else fName := '';
     end;
   end else entries := 1;

  FillChar(FileInformation^,SizeOf(FileInformation),0);
  if (entries > 0) then FileInformation.dwFileAttributes := FILE_ATTRIBUTE_DIRECTORY;
  FileInformation.nFileSizeLow := fSize;
  //BOOL DosDateTimeToFileTime(WORD wDOSDate, WORD wDOSTime, LPFILETIME lpft)
  tmpDate := DateTimeToFileDate(now);
  DosDateTimeToFileTime(LongRec(tmpDate).Hi,LongRec(tmpDate).Lo,FileInformation.ftCreationTime);
  DosDateTimeToFileTime(LongRec(tmpDate).Hi,LongRec(tmpDate).Lo,FileInformation.ftLastAccessTime);
  DosDateTimeToFileTime(LongRec(tmpDate).Hi,LongRec(tmpDate).Lo,FileInformation.ftLastWriteTime);
  Result := 0;
end;

procedure MakeDirectoryEntry(var FindData: WIN32_FIND_DATAW; fName: string; fType: Integer; fSize: DWORD);
var tmpDate: integer;
begin
  FillChar(FindData,sizeof(FindData),0);
  if (fType = 1) then FindData.dwFileAttributes := FILE_ATTRIBUTE_DIRECTORY else
    FindData.dwFileAttributes := 0;
  StringToWideChar(fName,FindData.cFileName,length(fName)*2);
  FindData.nFileSizeLow := fSize;
  //BOOL DosDateTimeToFileTime(WORD wDOSDate, WORD wDOSTime, LPFILETIME lpft)
  tmpDate := DateTimeToFileDate(now);
  DosDateTimeToFileTime(LongRec(tmpDate).Hi,LongRec(tmpDate).Lo,FindData.ftCreationTime);
  DosDateTimeToFileTime(LongRec(tmpDate).Hi,LongRec(tmpDate).Lo,FindData.ftLastAccessTime);
  DosDateTimeToFileTime(LongRec(tmpDate).Hi,LongRec(tmpDate).Lo,FindData.ftLastWriteTime);
end;

function MirrorFindFiles(PathName: PWideChar;
                         FillFindDataCallback: TDokanFillFindData;
                         var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: WideString;
  FindData: WIN32_FIND_DATAW;
  FindHandle: THandle;
  TmpL: TStringList;
  TmpS,fName: string;
  obj: ISuperObject;
  arr: TSuperArray;
  hash: string;
  i,j,entries: Integer;
begin
  FilePath := PathName;
  if (Copy(FilePath,Length(FilePath)-1,2)='\*') then Delete(FilePath,length(FilePath)-1,2);
  FilePath := LongHandStrNxt(FilePath,'\','/');

  DbgPrint('FindFiles: %s', [FilePath]);

  if (FilePath = '') or (FilePath = '/') then begin
    MakeDirectoryEntry(FindData,'ipfs',1{directory},0);
    FillFindDataCallback(FindData, DokanFileInfo);
    MakeDirectoryEntry(FindData,'ipns',1{directory},0);
    FillFindDataCallback(FindData, DokanFileInfo);
    result := 0;
    exit;
   end;

  MakeDirectoryEntry(FindData,'.',1{directory},0);
  FillFindDataCallback(FindData, DokanFileInfo);
  MakeDirectoryEntry(FindData,'..',1{directory},0);
  FillFindDataCallback(FindData, DokanFileInfo);
  if (FilePath = '/ipfs') or (FilePath = '/ipns') then begin
    result := 0;
    exit;
   end;

  TmpL := TStringList.Create;
  GetUrlHtmlWithComp('http://127.0.0.1:5001/api/v0/ls?arg='+FilePath,TmpL);
  TmpS := TmpL.Text;
  TmpL.Free;
  try
    obj := SO(TmpS);
    hash := obj.a['Objects'].o[0].s['Hash'];
    entries := 0;
    arr := obj.a['Objects'].o[0].o['Links'].AsArray;
    if assigned(arr) then entries := arr.Length;
    if (hash = '') then begin
      Result := -1;
      DbgPrint('FindFirstFile failed, error code = %s', [TmpS]);
     end else begin
       for i := 0 to entries-1 do begin
         fName := arr[i].s['Name'];// + ' ['+ arr[i].S['Hash'] + ']';
         MakeDirectoryEntry(FindData,fName,arr[i].I['Type'],arr[i].I['Size']);
         FillFindDataCallback(FindData, DokanFileInfo);
        end;
      end;
  except
    Result := -1;
    if (TmpS='') then TmpS := 'cannotConnect?';
    DbgPrint('FindFirstFile failed, error code = %s', [TmpS]);
  end;
end;

function MirrorSetFileAttributes(FileName: PWideChar;
                                 FileAttributes: Cardinal;
                                 var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
begin
  result := -1;
end;

function MirrorSetFileTime(FileName: PWideChar;
                           CreationTime, LastAccessTime, LastWriteTime: PFileTime;
                           var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
begin
  result := -1;
end;

function MirrorDeleteFile(FileName: PWideChar;
                          var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
begin
  result := 0;
end;

function MirrorDeleteDirectory(FileName: PWideChar;
                               var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
begin
  result := -1;
end;

function MirrorMoveFile(ExistingFileName, NewFileName: PWideChar;
                        ReplaceExisiting: LongBool;
                        var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
begin
  result := -1;
end;

function MirrorSetEndOfFile(FileName: PWideChar;
                            Length: Int64;
                            var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
begin
  result := -1;
end;

function MirrorLockFile(FileName: PWideChar;
                        Offset, Length: Int64;
                        var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
begin
  result := -1;
end;

function MirrorUnlockFile(FileName: PWideChar;
                          Offset, Length: Int64;
                          var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
begin
  result := -1;
end;

function MirrorUnmount(var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
begin
  result := 0;
  DbgPrint('Unmount');
end;

// Global vars
var
  g_DokanOperations: TDokanOperations = (
    CreateFile: MirrorCreateFile;
    OpenDirectory: MirrorOpenDirectory;
    CreateDirectory: MirrorCreateDirectory;
    Cleanup: MirrorCleanup;
    CloseFile: MirrorCloseFile;
    ReadFile: MirrorReadFile;
    WriteFile: MirrorWriteFile;
    FlushFileBuffers: MirrorFlushFileBuffers;
    GetFileInformation: MirrorGetFileInformation;
    FindFiles: MirrorFindFiles;
    FindFilesWithPattern: nil;
    SetFileAttributes: MirrorSetFileAttributes;
    SetFileTime: MirrorSetFileTime;
    DeleteFile: MirrorDeleteFile;
    DeleteDirectory: MirrorDeleteDirectory;
    MoveFile: MirrorMoveFile;
    SetEndOfFile: MirrorSetEndOfFile;
    SetAllocationSize: nil;
    LockFile: MirrorLockFile;
    UnlockFile: MirrorUnlockFile;
    GetFileSecurity: nil;
    SetFileSecurity: nil;
    GetDiskFreeSpace: nil;
    GetVolumeInformation: nil;
    Unmount: MirrorUnmount
  );

  g_DokanOptions: TDokanOptions = (
    Version : 0;
    ThreadCount: 0;
    Options: 0;
    GlobalContext: 0;
    MountPoint: #0;
  );

// Utilities routines
procedure DbgPrint(const Message: string); overload;
begin
  if (g_DokanOptions.Options and DOKAN_OPTION_DEBUG) = DOKAN_OPTION_DEBUG then
  begin
    if (g_DokanOptions.Options and DOKAN_OPTION_STDERR) = DOKAN_OPTION_STDERR then
      Writeln(ErrOutput,Message)
    else
      Writeln(Message)
  end;
end;

procedure DbgPrint(const Format: string; const Args: array of const); overload;
begin
  if (g_DokanOptions.Options and DOKAN_OPTION_DEBUG) = DOKAN_OPTION_DEBUG then
  begin
    if (g_DokanOptions.Options and DOKAN_OPTION_STDERR) = DOKAN_OPTION_STDERR then
      Writeln(ErrOutput,SysUtils.Format(Format,Args))
    else
      Writeln(SysUtils.Format(Format,Args))
  end;
end;

function CharInSet(C: Char; const CharSet: TSysCharSet): Boolean;
begin
  Result := c in CharSet
end;
   
// Main procedure
procedure Main;
var
  i: Integer;

  function FindSwitch(const s: string; t: array of Char): Integer;
  var
    i: Integer;
    c: Char;
  begin
    if (Length(s) = 2) and CharInSet(s[1],['/','-','\']) then
    begin
      c := UpCase(s[2]);
      for i:=Low(t) to High(t) do
        if t[i] = c then
        begin
          Result := i;
          Exit;
        end;
    end;
    Result := Low(t) - 1;
  end;

begin
  IsMultiThread := True;
  i := 1;
  g_DokanOptions.Version := DOKAN_VERSION;
  g_DokanOptions.ThreadCount := 0;

  while i <= ParamCount do
  begin
    case FindSwitch(ParamStr(i), ['R','L','T','D','S','N','M','K','A']) of
      0: begin
        if (i = ParamCount) or (ParamStr(i+1) = '') then
          raise Exception.Create('Missing root directory after /R');
        Inc(i);
      end;
      1: begin
        if (i = ParamCount) or (Length(ParamStr(i+1)) <> 1) then
          raise Exception.Create('Missing drive letter after /L');
        Inc(i);
        g_DokanOptions.MountPoint := PWideChar(WideString(ParamStr(i)));
      end;
      2: begin
        if (i = ParamCount) or (ParamStr(i+1) = '') then
          raise Exception.Create('Missing thread count after /T');
        Inc(i);
        g_DokanOptions.ThreadCount := StrToInt(ParamStr(i));
      end;
      3: g_DokanOptions.Options := g_DokanOptions.Options or DOKAN_OPTION_DEBUG;
      4: g_DokanOptions.Options := g_DokanOptions.Options or DOKAN_OPTION_STDERR;
      5: g_DokanOptions.Options := g_DokanOptions.Options or DOKAN_OPTION_NETWORK;
      6: g_DokanOptions.Options := g_DokanOptions.Options or DOKAN_OPTION_REMOVABLE;
      7: g_DokanOptions.Options := g_DokanOptions.Options or DOKAN_OPTION_KEEP_ALIVE;
      8: g_DokanOptions.Options := g_DokanOptions.Options or DOKAN_OPTION_ALT_STREAM;
    end;
    Inc(i);
  end;
  if (g_DokanOptions.MountPoint = WideString('')) then
  begin
    WriteLn('dipfs v',dipfsVersion,' - mount ipfs to a Windows drive via Dokan');
    WriteLn('Usage: ',ExtractFileName(ParamStr(0)));
    WriteLn('   /L DriveLetter      (e.g. /L m)');
    WriteLn('   /D                  (optional, enable debug output)');
    //WriteLn('   /R RootDirectory    (e.g. /R C:\test)');
    //WriteLn('   /T ThreadCount      (optional, e.g. /T 5)');
    //WriteLn('   /S                  (optional, use stderr for output)');
    //WriteLn('   /N                  (optional, use network drive)');
    //WriteLn('   /M                  (optional, use removable drive)');
    //WriteLn('   /K                  (optional, keep alive)');
    //WriteLn('   /A                  (optional, use alternate stream)');
  end else
  begin
    Writeln('dipfs v',dipfsVersion,': Mounting ipfs ['+g_DokanOptions.MountPoint+':\ipfs\, '+g_DokanOptions.MountPoint+':\ipns\] via http://127.0.0.1:5001/api');
    i := DokanMain(g_DokanOptions, g_DokanOperations);
    if i <> DOKAN_SUCCESS then
      raise EDokanMainError.Create(i);
  end;
end;


begin
  HTFileMap := THashMap.Create(True,false);
  try
    Main;
  except
    on e: Exception do
      WriteLn('Error (',e.ClassName,'): ',e.Message);
    else
      WriteLn('Unspecified error');
  end;
  HTFileMap.Free;
end.

