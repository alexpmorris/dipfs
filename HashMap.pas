unit HashMap;
////////////////////////////////////////////////////////////////////////////////
//
//   Unit        :  THashMap
//   Author      :  rllibby
//   Date        :  06.16.2008
//   Description :  Object hash that allows for fast lookups, as well as indexed
//                  traversal of the items.
//   http://planetmath.org/encyclopedia/GoodHashTablePrimes.html
//   APM 2009 - added Dynamic Array for adjustable BucketSize at Runtime
//			  - added FastCode/FastMove
//			  - added Hash/Key compare for faster bucket traversals
////////////////////////////////////////////////////////////////////////////////
interface

////////////////////////////////////////////////////////////////////////////////
//   Include units
////////////////////////////////////////////////////////////////////////////////
uses
  FastCode, FastMove, Windows, SysUtils, Classes;

////////////////////////////////////////////////////////////////////////////////
//   Hash constansts
////////////////////////////////////////////////////////////////////////////////
//const
//  HASH_SIZE         =  1543{521};  // Can be changed, but should always be a prime number

////////////////////////////////////////////////////////////////////////////////
//   THashMapNode
////////////////////////////////////////////////////////////////////////////////
type
  PHashMapNode      =  ^THashMapNode;
  THashMapNode      =  packed record
     Key:           PChar;
     Hash:          LongWord;
     Data:          TObject;
     Next:          PHashMapNode;
  end;

////////////////////////////////////////////////////////////////////////////////
//   String compare prototype
////////////////////////////////////////////////////////////////////////////////
type
  TStrCompare       =  function(const Str1, Str2: PChar): Integer;

////////////////////////////////////////////////////////////////////////////////
//   THashMap
////////////////////////////////////////////////////////////////////////////////
type
  THashMap          =  class(TObject)
  private
     // Private declarations
     FHash:         Array of PHashMapNode;
     FList:         TList;
     FCompare:      TStrCompare;
     FCaseSensitive:Boolean;
     FOwnsObjects:  Boolean;
     HASH_SIZE:     Integer;
  protected
     // Protected declarations
     function       GetCount: Integer;
     function       GetItems(Index: Integer): TObject;
     function       GetKeys(Index: Integer): String;
     function       HashFunc(Key: PChar): LongWord;
     function       HashCompare(Item1, Item2: PChar): Boolean;
     function       NewNode(Key: PChar; Data: TObject; Hash: LongWord): PHashMapNode;
     procedure      FreeNode(Node: PHashMapNode);
     procedure      SetCaseSensitive(Value: Boolean);
  public
     // Public declarations
     constructor    Create(ACaseSensitive: Boolean = False; AOwnsObjects: Boolean = True; AHash_Size: Integer = 521);
     destructor     Destroy; override;
     procedure      Clear;
     function       Delete(Key: String): Boolean;
     function       Add(Key: String; Data: TObject): Boolean;
     function       Get(Key: String): TObject;
     function       Find(Key: String; out Data): Boolean;
     function       Extract(Key: String; out Data): Boolean;
  public
     // Public properties
     property       CaseSensitive: Boolean read FCaseSensitive write SetCaseSensitive;
     property       OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
     property       Count: Integer read GetCount;
     property       Items[Index: Integer]: TObject read GetItems;
     property       Keys[Index: Integer]: String read GetKeys;
  end;

implementation

//// THashMap //////////////////////////////////////////////////////////////////
constructor THashMap.Create(ACaseSensitive: Boolean = False; AOwnsObjects: Boolean = True; AHash_Size: Integer = 521);
begin

  // Perform inherited
  inherited Create;

  // Initial values
  SetLength(FHash,AHash_Size);
  HASH_SIZE := AHash_Size;
  //FillChar(FHash, SizeOf(FHash), 0);
  FList:=TList.Create;
  FCaseSensitive:=ACaseSensitive;
  FOwnsObjects:=AOwnsObjects;

  // Determine the compare function to use
  if FCaseSensitive then
     // Use StrComp
     @FCompare:=@StrComp
  else
     // Use StrIComp
     @FCompare:=@StrIComp;

end;

destructor THashMap.Destroy;
begin

  // Resource protection
  try
     // Clear the hash
     Clear;
     // Free the list
     FList.Free;
     // Free the dynamic array
     SetLength(FHash, 0);
  finally
     // Perform inherited
     inherited Destroy;
  end;

end;

procedure THashMap.Clear;
var  lpNode:        PHashMapNode;
     lpNext:        PHashMapNode;
     dwIndex:       Integer;
begin

  // Resource protection
  try
     // Resource protection
     try
        // Iterate the array and clear the hash nodes
        for dwIndex:=0 to Pred(HASH_SIZE) do
        begin
           // Get bucket node
           lpNode:=FHash[dwIndex];
           // Walk the nodes
           while Assigned(lpNode) do
           begin
              // Get pointer to next item
              lpNext:=lpNode^.Next;
              // Free node
              FreeNode(lpNode);
              // Set iterator to next item
              lpNode:=lpNext;
           end;
           // Clear hash bucket pointer in dynamic array
           FHash[dwIndex] := nil;
        end;
     finally
        // Clear all hash buckets
        //FillChar(FHash, SizeOf(FHash), 0);
     end;
  finally
     // Clear the list
     FList.Clear;
  end;

end;

{$OVERFLOWCHECKS OFF}
function THashMap.HashFunc(Key: PChar): LongWord;
var  bChar:         Byte;
begin

  // Set starting result
  result:=0;

  // Check key pointer
  if Assigned(Key) then
  begin
     // Generate hash index for key
     while (Key^ > #0) do
     begin
        // Check ascii char
        if (Key^ in ['A'..'Z']) then
           // Lowercase the value
           bChar:=Byte(Key^) + 32
        else
           // Keep value as is
           bChar:=Byte(Key^);
        // Update hash value
        Inc(result, (result shl 3) + bChar);
        // Next char
        Inc(Key);
     end;
  end;

  // Keep result in bounds of array
  //result:=result mod HASH_SIZE;

end;
{$OVERFLOWCHECKS ON}

function THashMap.HashCompare(Item1, Item2: PChar): Boolean;
begin

  // Check item1 for null
  if (Item1 = nil) then
     // Check for Item2 being nil
     result:=(Item2 = nil)
  // Check item2 for null
  else if (Item2 = nil) then
     // Item1 is not null, so no possible match
     result:=False
  else
     // Compare the strings
     result:=(FCompare(Item1, Item2) = 0);

end;

function THashMap.NewNode(Key: PChar; Data: TObject; Hash: LongWord): PHashMapNode;
begin

  // Get memory for new node
  GetMem(result, SizeOf(THashMapNode));

  // Resource protection
  try
     // Resource protection
     try
        // Check key
        if Assigned(Key) then
           // Set key and data fields
           result^.Key:=StrCopy(AllocMem(Succ(StrLen(Key))), Key)
        else
           // Allocate byte for null terminator
           result^.Key:=AllocMem(SizeOf(Char));
        // Set data field
        result^.Data:=Data;
        // Assign full hash
        result^.Hash:=Hash;
     finally
        // Make sure the next node link is cleared
        result^.Next:=nil;
     end;
  finally
     // Add item to list
     FList.Add(result);
  end;

end;

procedure THashMap.FreeNode(Node: PHashMapNode);
begin

  // Remove the node from the list
  FList.Remove(Node);

  // Resource protection
  try
     // Free node key
     FreeMem(Node^.Key);
     // If owns object is true, then free the object
     if FOwnsObjects then Node^.Data.Free;
  finally
     // Free node memory
     FreeMem(Node);
  end;

end;

function THashMap.Extract(Key: String; out Data): Boolean;
var  lpNode:        PHashMapNode;
     lpIter:        PHashMapNode;
     dwIndex,Hash:  LongWord;
begin

  // Set default result
  result:=False;

  // Get the hash index
  Hash:=HashFunc(Pointer(Key));
  dwIndex:=Hash mod HASH_SIZE;

  // Check top level bucket
  if Assigned(FHash[dwIndex]) then
  begin
     // Prepare for node iteration
     lpNode:=FHash[dwIndex];
     lpIter:=lpNode;
     // Walk the nodes
     while Assigned(lpIter) do
     begin
        // Match key
        if (lpIter^.Hash = Hash) and HashCompare(lpIter^.Key, Pointer(Key)) then break;
        // Save current node
        lpNode:=lpIter;
        // Move to the next node in the chain
        lpIter:=lpNode^.Next;
     end;
     // Check to see if the node is still set
     if Assigned(lpIter) then
     begin
        // Check to see if this is the top level item
        if (lpIter = lpNode) then
           // Link next node into the bucket
           FHash[dwIndex]:=lpIter^.Next
        else
           // Link over this node
           lpNode^.Next:=lpIter^.Next;
        // Set the outbound data
        TObject(Data):=lpIter^.Data;
        // Clear the node data (extract will not free the object)
        lpIter^.Data:=nil;
        // Free the node
        FreeNode(lpIter);
        // Success
        result:=True;
     end;
  end;

end;

function THashMap.Delete(Key: String): Boolean;
var  lpNode:        PHashMapNode;
     lpIter:        PHashMapNode;
     dwIndex,Hash:  LongWord;
begin

  // Set default result
  result:=False;

  // Get the hash index
  Hash:=HashFunc(Pointer(Key));
  dwIndex:=Hash mod HASH_SIZE;

  // Check top level bucket
  if Assigned(FHash[dwIndex]) then
  begin
     // Prepare for node iteration
     lpNode:=FHash[dwIndex];
     lpIter:=lpNode;
     // Walk the nodes
     while Assigned(lpIter) do
     begin
        // Match key/hash
        if (lpIter^.Hash = Hash) and HashCompare(lpIter^.Key, Pointer(Key)) then break;
        // Save current node
        lpNode:=lpIter;
        // Move to the next node in the chain
        lpIter:=lpNode^.Next;
     end;
     // Check to see if the node is still set
     if Assigned(lpIter) then
     begin
        // Check to see if this is the top level item
        if (lpIter = lpNode) then
           // Link next node into the bucket
           FHash[dwIndex]:=lpIter^.Next
        else
           // Link over this node
           lpNode^.Next:=lpIter^.Next;
        // Free the node
        FreeNode(lpIter);
        // Success
        result:=True;
     end;
  end;

end;

function THashMap.Add(Key: String; Data: TObject): Boolean;
var  lpNode:        PHashMapNode;
     lpIter:        PHashMapNode;
     dwIndex,Hash:  LongWord;
begin

  // Get the hash bucket item index
  Hash:=HashFunc(Pointer(Key));
  dwIndex:=Hash mod HASH_SIZE;

  // Resource protection
  try
     // Get the hash bucket item
     lpNode:=FHash[dwIndex];
     // Is the bucket empty?
     if (lpNode = nil) then
        // Add new node into bucket
        FHash[dwIndex]:=NewNode(Pointer(Key), Data, Hash)
     else
     begin
        // Save current node
        lpIter:=lpNode;
        // Walk nodes
        while Assigned(lpIter) do
        begin
           // Match the key
           if (lpIter^.Hash = Hash) and HashCompare(lpIter^.Key, Pointer(Key)) then
           begin
              // Check for same object
              if not(lpIter^.Data = Data) then
              begin
                 // Not same object, do we own the original (and should we free it)
                 if FOwnsObjects then lpIter^.Data.Free;
                 // Assign new object
                 lpIter^.Data:=Data;
              end;
              // Done processing
              break;
           end;
           // Save current node
           lpNode:=lpIter;
           // Walk next node
           lpIter:=lpNode^.Next;
        end;
        // Do we need to add a new item to the end of the chain?
        if not(Assigned(lpIter)) then
        begin
           // Create new hash node and add to end of the chain
           lpNode^.Next:=NewNode(Pointer(Key), Data, Hash);
        end;
     end;
  finally
     // Always success
     result:=True;
  end;

end;

function THashMap.Get(Key: String): TObject;
begin

  // Just another way of calling Find(...)
  if not(Find(Key, result)) then result:=nil;

end;

function THashMap.Find(Key: String; out Data): Boolean;
var  lpNode:        PHashMapNode;
     dwIndex,Hash:  LongWord;
begin

  // Get the hash bucket item
  Hash:=HashFunc(Pointer(Key));
  dwIndex:=Hash mod HASH_SIZE;
  lpNode:=FHash[dwIndex];

  // Resource protection
  try
     // Walk the items
     while Assigned(lpNode) do
     begin
        // Compare the key/hash
        if (lpNode^.Hash = Hash) and HashCompare(lpNode^.Key, Pointer(Key)) then
        begin
           // Key exists, set out return data
           TObject(Data):=lpNode^.Data;
           // Done processing
           break;
        end;
        // Walk the next item
        lpNode:=lpNode^.Next;
     end;
  finally
     // Success if node is assigned
     result:=Assigned(lpNode);
  end;

end;

function THashMap.GetCount: Integer;
begin

  // Return the count of items
  result:=FList.Count;

end;

function THashMap.GetItems(Index: Integer): TObject;
begin

  // Return the data object for the indexed item
  result:=PHashMapNode(FList[Index])^.Data;

end;

function THashMap.GetKeys(Index: Integer): String;
begin

  // Return the Key for the indexed item
  result:=PHashMapNode(FList[Index])^.Key;

end;

procedure THashMap.SetCaseSensitive(Value: Boolean);
begin

  // Set case sensitivity
  if not(FCaseSensitive = Value) then
  begin
     // Change
     FCaseSensitive:=Value;
     // Update the compare function
     if FCaseSensitive then
        // Use StrComp
        @FCompare:=@StrComp
     else
        // Use StrIComp
        @FCompare:=@StrIComp;
  end;

end;

end.


{ //HashMap appears to be over 5x faster than TStringHashTrie!!!
// uses HashMap
var  objScreen:     TScreen;
     objMouse:      TMouse;
     dwIndex:       Integer;
begin

  // Create with case insensitivty / does not own objects
  with THashMap.Create(False, False) do
  begin
     // Adding items to hash map
     Add('Mouse', Mouse);
     Add('Screen', Screen);
     Add('Form1', Self);
     Add('Application', Application);

     // Using the Find accessor
     if Find('Screen', objScreen) then  ShowMessage(objScreen.ClassName);

     // Using the Get accessor
     objMouse:=TMouse(Get('Mouse'));
     // Need to check assignment
     if Assigned(objMouse) then ShowMessage(objMouse.ClassName);

     // Example using iteration
     for dwIndex:=0 to Pred(Count) do
        ShowMessage(Keys[dwIndex] + '=' + Items[dwIndex].ClassName);

     // Free the hash map
     Free;
  end;
}

{
In the course of designing a good hashing configuration, it is helpful to have a list of prime numbers for the hash table size.

The following is such a list. It has the properties that:

   1. each number in the list is prime (as you no doubt expected by now)
   2. each number is slightly less than twice the size of the previous
   3. each number is as far as possible from the nearest two powers of two

Using primes for hash tables is a good idea because it minimizes clustering in the hashed table. Item (2) is nice because it is convenient for growing a hash table in the face of expanding data. Item (3) has, allegedly, been shown to yield especially good results in practice.

And here is the list:
lwr 	upr 	% err    	prime
2^5 	2^6 	10.41667 	53
2^6 	2^7 	1.041667 	97
2^7 	2^8 	0.520833 	193
2^8 	2^9 	1.302083 	389
2^9 	2^10 	0.130208 	769
2^10 	2^11 	0.455729 	1543
2^11 	2^12 	0.227865 	3079
2^12 	2^13 	0.113932 	6151
2^13 	2^14 	0.008138 	12289
2^14 	2^15 	0.069173 	24593
2^15 	2^16 	0.010173 	49157
2^16 	2^17 	0.013224 	98317
2^17 	2^18 	0.002543 	196613
2^18 	2^19 	0.006358 	393241
2^19 	2^20 	0.000127 	786433
2^20 	2^21 	0.000318 	1572869
2^21 	2^22 	0.000350 	3145739
2^22 	2^23 	0.000207 	6291469
2^23 	2^24 	0.000040 	12582917
2^24 	2^25 	0.000075 	25165843
2^25 	2^26 	0.000010 	50331653
2^26 	2^27 	0.000023 	100663319
2^27 	2^28 	0.000009 	201326611
2^28 	2^29 	0.000001 	402653189
2^29 	2^30 	0.000011 	805306457
2^30 	2^31 	0.000000 	1610612741

The columns are, in order, the lower bounding power of two, the upper bounding power of two, the relative deviation (in percent) of the prime number from the optimal middle of the first two, and finally the prime itself.
}
