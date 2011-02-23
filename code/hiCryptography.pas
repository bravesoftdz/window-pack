unit hiCryptography;

interface

uses Windows,Kol,Share,Debug;

const
  CRYPT_MODE   = 0;
  DECRYPT_MODE = 1;
  
type
  HCRYPTPROV  = Cardinal;
  HCRYPTKEY   = Cardinal;
  ALG_ID      = Cardinal;
  PHCRYPTPROV = ^HCRYPTPROV;
  PHCRYPTKEY  = ^HCRYPTKEY;
  HCRYPTHASH  = Cardinal;
  PHCRYPTHASH = ^HCRYPTHASH;
  PLongWord   = ^LongWord;

type
 TThreadRec = record
   handle:cardinal;
   ss:cardinal;
   size:cardinal;     
   key:PChar;
   key_len:integer;
 end;
 PThreadRec = ^TThreadRec;
 
  THICryptography = class(TDebug)
   private
    FResult: string;
    FEvents: array of cardinal;
    procedure InitPass(var hProv: HCRYPTPROV; var hSKey: HCRYPTKEY; pass: string; alg: LongWord; Provider: PChar; ProvType: LongWord);
    procedure CryptXOR(var _Data:TData; Mode: Byte);
    procedure Crypt_Decrypt_MS_Prov(var _Data:TData; alg: LongWord; Mode: Byte; Provider: PChar; ProvType: LongWord);     
   public
    _prop_Mode:byte;
    _prop_HashMode:byte;
    _prop_Key:string;

    _data_Key:THI_Event;
    _data_Data:THI_Event;
    _data_DataCrypt:THI_Event;    
    _event_onCrypt:THI_Event;
    _event_onDeCrypt:THI_Event;    

    procedure _work_doCrypt0(var _Data:TData; Index:word);  // XOR
    procedure _work_doCrypt1(var _Data:TData; Index:word);  // RC2
    procedure _work_doCrypt2(var _Data:TData; Index:word);  // RC4
    procedure _work_doCrypt3(var _Data:TData; Index:word);  // DES_56
    procedure _work_doCrypt4(var _Data:TData; Index:word);  // 3DES_112
    procedure _work_doCrypt5(var _Data:TData; Index:word);  // 3DES_168                    
    procedure _work_doCrypt6(var _Data:TData; Index:word);  // AES_128    
    procedure _work_doCrypt7(var _Data:TData; Index:word);  // AES_192
    procedure _work_doCrypt8(var _Data:TData; Index:word);  // AES_256        
    procedure _work_doCrypt9(var _Data:TData; Index:word);  // CYLINK_MEK        

    procedure _work_doDeCrypt0(var _Data:TData; Index:word);  // XOR
    procedure _work_doDeCrypt1(var _Data:TData; Index:word);  // RC2
    procedure _work_doDeCrypt2(var _Data:TData; Index:word);  // RC4
    procedure _work_doDeCrypt3(var _Data:TData; Index:word);  // DES_56
    procedure _work_doDeCrypt4(var _Data:TData; Index:word);  // 3DES_112
    procedure _work_doDeCrypt5(var _Data:TData; Index:word);  // 3DES_168                    
    procedure _work_doDeCrypt6(var _Data:TData; Index:word);  // AES_128    
    procedure _work_doDeCrypt7(var _Data:TData; Index:word);  // AES_192
    procedure _work_doDeCrypt8(var _Data:TData; Index:word);  // AES_256        
    procedure _work_doDeCrypt9(var _Data:TData; Index:word);  // CYLINK_MEK        


    procedure _var_Result(var _Data:TData; Index:word);
  end;

implementation

function xor_proc(l:pointer):Integer; stdcall;
var mx:cardinal;
    str,ps,len:cardinal; 
begin
  Result := 0;
  mx := PThreadRec(l).size shr 2; 
  str := PThreadRec(l).ss;
  ps := cardinal(PThreadRec(l).key);
  len := PThreadRec(l).key_len;
  asm
    push ecx
    push edx
    push eax
    push esi
    push edi
    
    mov ecx, [mx]
    mov esi, [str]
    mov edx, [ps]
    xor edi, edi    
   @1:
    mov eax, [edx + edi]
    xor [esi], eax
    add esi, 4
    add edi, 4
    cmp edi, [len]
    jnz @2
    xor edi, edi
   @2: 
    loop @1
    
    pop edi 
    pop esi 
    pop eax    
    pop edx
    pop ecx
  end;
  ExitThread(0);
end;

procedure THICryptography.CryptXOR;
var rc:PThreadRec;
    i,c,a:integer;
    id:LongWord;
    key:string;
    lpSystemInfo:_SYSTEM_INFO;
    lst:PList;
begin
   Case Mode of
     0: FResult := ReadString(_Data, _data_Data);
     1: FResult := ReadString(_Data, _data_DataCrypt);
   end;       

   key := ReadString(_Data, _data_Key, _prop_Key);
   while length(key) mod 4 > 0 do
     key := key + ' ';
   a := 0;
   while length(FResult) mod 4 > 0 do
     begin
       FResult := FResult + ' ';
       inc(a);
     end;
   if length(FResult) > 64*1024 then
     begin
       GetSystemInfo(lpSystemInfo);
       c := lpSystemInfo.dwNumberOfProcessors;
     end
   else c := 1;
   lst := NewList;
   SetLength(FEvents, c);
   for i := 1 to c do
     begin
       new(rc);
       rc.ss := cardinal(@FResult[1 + (i - 1)*(length(FResult) div c)]);
       rc.size := length(FResult) div c;
       rc.key := @key[1];
       rc.key_len := length(key);
       //rc.handle := BeginThread(nil, 0, xor_proc, rc, 0, id);
       rc.handle := CreateThread(nil, 0, @xor_proc, rc, 0, id);
       FEvents[i-1] := rc.handle;
       lst.Add(rc); 
       SetThreadPriority(rc.handle, THREAD_PRIORITY_HIGHEST);
     end;
   WaitForMultipleObjects(c, PWOHandleArray(@FEvents[0]), true, cardinal(-1));
   if a > 0 then
     delete(FResult, Length(FResult) - a + 1, a);

   Case Mode of
     0: _hi_onEvent(_event_onCrypt, FResult);
     1: _hi_onEvent(_event_onDeCrypt, FResult);
   end;

   for i := 0 to c-1 do
     begin
       CloseHandle(FEvents[i]);
       dispose(PThreadRec(lst.Items[i]));
     end;
   lst.Free;   

end;

procedure THICryptography._work_doCrypt0;
begin
  CryptXOR(_Data, CRYPT_MODE);
end;

procedure THICryptography._work_doDeCrypt0;
begin
  CryptXOR(_Data, DECRYPT_MODE);
end;

// ============================================ MS CryptoAPI ==========================================

const
  ADVAPI32            = 'advapi32.dll';
  CRYPT_VERIFYCONTEXT = $F0000000;
  CALG_MD2            = 32769;
  CALG_MD4            = 32770;
  CALG_MD5            = 32771;
  CALG_SHA            = 32772;
  CALG_RC2            = 26114;
  CALG_RC4            = 26625;
  CALG_RC5            = 26125;
  CALG_DES            = 26113;
  CALG_3DES_112       = 26121;
  CALG_3DES           = 26115;
  CALG_DESX           = 26116;
  CALG_AES            = 26129;
  CALG_AES_128        = 26126;
  CALG_AES_192        = 26127;
  CALG_AES_256        = 26128;  
  CALG_CYLINK_MEK     = 26124;

  PROV_RSA_FULL         = 1;
  PROV_RSA_SIG          = 2;
  PROV_DSS              = 3;
  PROV_FORTEZZA         = 4;
  PROV_MS_EXCHANGE      = 5;
  PROV_SSL              = 6;
  PROV_RSA_SCHANNEL     = 12;
  PROV_DSS_DH           = 13;
  PROV_EC_ECDSA_SIG     = 14;
  PROV_EC_ECNRA_SIG     = 15;
  PROV_EC_ECDSA_FULL    = 16;
  PROV_EC_ECNRA_FULL    = 17;
  PROV_DH_SCHANNEL      = 18;
  PROV_SPYRUS_LYNKS     = 20;
  PROV_RNG              = 21;
  PROV_INTEL_SEC        = 22;
  PROV_REPLACE_OWF      = 23;
  PROV_RSA_AES          = 24;

  MS_DEF_DH_SCHANNEL_PROV   = 'Microsoft DH Schannel Cryptographic Provider'; 
  MS_DEF_DSS_DH_PROV        = 'Microsoft Base DSS and Diffie-Hellman Cryptographic Provider'; 
  MS_DEF_DSS_PROV           = 'Microsoft Base DSS Cryptographic Provider'; 
  MS_DEF_PROV               = 'Microsoft Base Cryptographic Provider v1.0'; 
  MS_DEF_RSA_SCHANNEL_PROV  = 'Microsoft RSA Schannel Cryptographic Provider'; 
  MS_DEF_RSA_SIG_PROV       = 'Microsoft RSA Signature Cryptographic Provider'; 
  MS_ENH_DSS_DH_PROV        = 'Microsoft Enhanced DSS and Diffie-Hellman Cryptographic Provider'; 
  MS_ENH_RSA_AES_PROV       = 'Microsoft Enhanced RSA and AES Cryptographic Provider'; 
  MS_ENHANCED_PROV          = 'Microsoft Enhanced Cryptographic Provider v1.0'; 
  MS_SCARD_PROV             = 'Microsoft Base Smart Card Crypto Provider'; 
  MS_STRONG_PROV            = 'Microsoft Strong Cryptographic Provider';
 
function CryptReleaseContext(hProv: HCRYPTPROV; dwFlags: LongWord): LongBool; stdcall; external ADVAPI32 name 'CryptReleaseContext';
function CryptAcquireContext(Prov: PHCRYPTPROV; Container: PChar; Provider: PChar; ProvType: LongWord; Flags: LongWord): LongBool; stdcall; external ADVAPI32 name 'CryptAcquireContextA';
function CryptEncrypt(Key: HCRYPTKEY; Hash: HCRYPTHASH; Final: LongBool; Flags: LongWord; Data: PChar; Len: PLongWord; BufLen: LongWord): LongBool;stdcall;external ADVAPI32 name 'CryptEncrypt';
function CryptDecrypt(Key: HCRYPTKEY; Hash: HCRYPTHASH; Final: LongBool; Flags: LongWord; Data: PChar; Len: PLongWord): LongBool; stdcall; external ADVAPI32 name 'CryptDecrypt';
function CryptCreateHash(Prov: HCRYPTPROV; Algid: ALG_ID; Key:HCRYPTKEY; Flags: LongInt; Hash: PHCRYPTHASH): LongBool; stdcall; external ADVAPI32 name 'CryptCreateHash';
function CryptHashData(Hash: HCRYPTHASH; Data: PChar; DataLen: LongInt; Flags: LongInt): LongBool; stdcall; external ADVAPI32 name 'CryptHashData';
function CryptDeriveKey(Prov: HCRYPTPROV; Algid: ALG_ID; BaseData: HCRYPTHASH; Flags: LongInt; Key: PHCRYPTKEY): LongBool; stdcall; external ADVAPI32 name 'CryptDeriveKey';
function CryptDestroyHash(hHash: HCRYPTHASH): LongBool; stdcall; external ADVAPI32 name 'CryptDestroyHash';
function CryptDestroyKey(hKey: HCRYPTKEY): LongBool; stdcall; external ADVAPI32 name 'CryptDestroyKey';

procedure THICryptography.InitPass;
var
  hash: HCRYPTHASH;
  hashalg: LongWord;  
begin
  Case _prop_HashMode of
    0: hashalg := CALG_MD5;
    1: hashalg := CALG_SHA;
    else
       hashalg := CALG_SHA;            
  end;
  CryptAcquireContext(@hProv, nil, Provider, ProvType, CRYPT_VERIFYCONTEXT);
  CryptCreateHash(hProv, hashalg, 0, 0, @hash);
  CryptHashData(hash, @pass[1], length(pass), 0);
  CryptDeriveKey(hProv, alg, hash, 0, @hSKey);
  CryptDestroyHash(hash);
end;

procedure THICryptography.Crypt_Decrypt_MS_Prov; // Universal Algorithm
var
  ln, sz: LongWord;
  pass: string; 
  hProv: HCRYPTPROV;
  hSKey: HCRYPTKEY;
begin
  Case Mode of
    0: FResult := ReadString(_Data, _data_Data) + #0;
    1: FResult := ReadString(_Data, _data_DataCrypt) + #0;
  end;  

  SetLength(FResult, Length(FResult) - 1); 
  sz := Length(FResult);
  pass := ReadString(_Data, _data_Key, _prop_Key);
  InitPass(hProv, hSKey, pass, alg, Provider, ProvType);

  Case Mode of
    0: begin
         ln := sz;
         CryptEncrypt(hSKey, 0, true, 0, @FResult[1], @ln, sz);
         if GetLastError = ERROR_MORE_DATA then
         begin
           SetLength(FResult, ln);
           CryptEncrypt(hSKey, 0, true, 0, @FResult[1], @sz, ln);
         end;
       end;
    1: CryptDecrypt(hSKey, 0, true, 0, @FResult[1], @sz);
  end;     
  SetLength(FResult, sz);

  CryptDestroyKey(hSKey);
  CryptReleaseContext(hProv, 0);

  Case Mode of
    0: _hi_CreateEvent(_Data, @_event_onCrypt, FResult);
    1: _hi_CreateEvent(_Data, @_event_onDeCrypt, FResult);
  end;  
end;

//-------------------------------------------- Crypt ---------------------------------------------------

procedure THICryptography._work_doCrypt1; // RC2
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_RC2, CRYPT_MODE, MS_ENHANCED_PROV, PROV_RSA_FULL);
end;

procedure THICryptography._work_doCrypt2; // RC4
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_RC4, CRYPT_MODE, MS_ENHANCED_PROV, PROV_RSA_FULL);  
end;

procedure THICryptography._work_doCrypt3; // DES_56
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_DES, CRYPT_MODE, MS_ENHANCED_PROV, PROV_RSA_FULL);
end;

procedure THICryptography._work_doCrypt4; // 3DES_112
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_3DES_112, CRYPT_MODE, MS_ENHANCED_PROV, PROV_RSA_FULL);
end;

procedure THICryptography._work_doCrypt5; // 3DES_168
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_3DES, CRYPT_MODE, MS_ENHANCED_PROV, PROV_RSA_FULL);
end;

procedure THICryptography._work_doCrypt6; // AES_128
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_AES_128, CRYPT_MODE, MS_ENH_RSA_AES_PROV, PROV_RSA_AES);
end;

procedure THICryptography._work_doCrypt7; // AES_192
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_AES_192, CRYPT_MODE, MS_ENH_RSA_AES_PROV, PROV_RSA_AES);
end;

procedure THICryptography._work_doCrypt8; // AES_256
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_AES_256, CRYPT_MODE, MS_ENH_RSA_AES_PROV, PROV_RSA_AES);
end;

procedure THICryptography._work_doCrypt9; // CYLINK_MEK
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_CYLINK_MEK, CRYPT_MODE, MS_DEF_DH_SCHANNEL_PROV, PROV_DH_SCHANNEL);
end;

//-------------------------------------------- DeCrypt ---------------------------------------------------

procedure THICryptography._work_doDeCrypt1; // RC2
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_RC2, DECRYPT_MODE, MS_ENHANCED_PROV, PROV_RSA_FULL);
end;

procedure THICryptography._work_doDeCrypt2; // RC4
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_RC4, DECRYPT_MODE, MS_ENHANCED_PROV, PROV_RSA_FULL);  
end;

procedure THICryptography._work_doDeCrypt3; // DES_56
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_DES, DECRYPT_MODE, MS_ENHANCED_PROV, PROV_RSA_FULL);
end;

procedure THICryptography._work_doDeCrypt4;
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_3DES_112, DECRYPT_MODE, MS_ENHANCED_PROV, PROV_RSA_FULL); // 3DES_112
end;

procedure THICryptography._work_doDeCrypt5;
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_3DES, DECRYPT_MODE, MS_ENHANCED_PROV, PROV_RSA_FULL); // 3DES_168
end;

procedure THICryptography._work_doDeCrypt6; // AES_128
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_AES_128, DECRYPT_MODE, MS_ENH_RSA_AES_PROV, PROV_RSA_AES);
end;

procedure THICryptography._work_doDeCrypt7; // AES_192
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_AES_192, DECRYPT_MODE, MS_ENH_RSA_AES_PROV, PROV_RSA_AES);
end;

procedure THICryptography._work_doDeCrypt8; // AES_256
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_AES_256, DECRYPT_MODE, MS_ENH_RSA_AES_PROV, PROV_RSA_AES);
end;

procedure THICryptography._work_doDeCrypt9; // CYLINK_MEK
begin
  Crypt_Decrypt_MS_Prov(_Data, CALG_CYLINK_MEK, DECRYPT_MODE, MS_DEF_DH_SCHANNEL_PROV, PROV_DH_SCHANNEL);
end;

procedure THICryptography._var_Result;
begin
   dtString(_Data, FResult);
end;

end.
