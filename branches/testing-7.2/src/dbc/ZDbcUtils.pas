{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{            Database Connectivity Functions              }
{                                                         }
{        Originally written by Sergey Seroukhov           }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2012 Zeos Development Group       }
{                                                         }
{ License Agreement:                                      }
{                                                         }
{ This library is distributed in the hope that it will be }
{ useful, but WITHOUT ANY WARRANTY; without even the      }
{ implied warranty of MERCHANTABILITY or FITNESS FOR      }
{ A PARTICULAR PURPOSE.  See the GNU Lesser General       }
{ Public License for more details.                        }
{                                                         }
{ The source code of the ZEOS Libraries and packages are  }
{ distributed under the Library GNU General Public        }
{ License (see the file COPYING / COPYING.ZEOS)           }
{ with the following  modification:                       }
{ As a special exception, the copyright holders of this   }
{ library give you permission to link this library with   }
{ independent modules to produce an executable,           }
{ regardless of the license terms of these independent    }
{ modules, and to copy and distribute the resulting       }
{ executable under terms of your choice, provided that    }
{ you also meet, for each linked independent module,      }
{ the terms and conditions of the license of that module. }
{ An independent module is a module which is not derived  }
{ from or based on this library. If you modify this       }
{ library, you may extend this exception to your version  }
{ of the library, but you are not obligated to do so.     }
{ If you do not wish to do so, delete this exception      }
{ statement from your version.                            }
{                                                         }
{                                                         }
{ The project web site is located on:                     }
{   http://zeos.firmos.at  (FORUM)                        }
{   http://sourceforge.net/p/zeoslib/tickets/ (BUGTRACKER)}
{   svn://svn.code.sf.net/p/zeoslib/code-0/trunk (SVN)    }
{                                                         }
{   http://www.sourceforge.net/projects/zeoslib.          }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZDbcUtils;

interface

{$I ZDbc.inc}

uses
  Types, Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} SysUtils, Contnrs,
  ZCompatibility, ZDbcIntfs, ZDbcResultSetMetadata, ZTokenizer;

{**
  Resolves a connection protocol and raises an exception with protocol
  is not supported.
  @param Url an initial database URL.
  @param SuupportedProtocols a driver's supported subprotocols.
}
function ResolveConnectionProtocol(Url: string;
  SupportedProtocols: TStringDynArray): string;

{**
  Resolves a database URL and fills the database connection parameters.
  @param Url an initial database URL.
  @param Info an initial info parameters.
  @param HostName a name of the database host.
  @param Port a port number.
  @param Database a database name.
  @param UserName a name of the database user.
  @param Password a user's password.
  @param ResutlInfo a result info parameters.
}
procedure ResolveDatabaseUrl(const Url: string; Info: TStrings;
  var HostName: string; var Port: Integer; var Database: string;
  var UserName: string; var Password: string; ResultInfo: TStrings);

{**
  Checks is the convertion from one type to another type allowed.
  @param InitialType an initial data type.
  @param ResultType a result data type.
  @return <code>True</code> if convertion is allowed
    or <code>False</code> otherwise.
}
function CheckConvertion(InitialType: TZSQLType; ResultType: TZSQLType): Boolean;

{**
  Defines a name of the column type.
  @param ColumnType a type of the column.
  @return a name of the specified type.
}
function DefineColumnTypeName(ColumnType: TZSQLType): string;

{**
  Raises a copy of the given exception.
  @param E an exception to be raised.
}
procedure RaiseSQLException(E: Exception);

{**
  Copies column information objects from one object list to another one.
  @param FromList the source object list.
  @param ToList the destination object list.
}
procedure CopyColumnsInfo(FromList: TObjectList; ToList: TObjectList);

{**
  Defines a statement specific parameter.
  @param Statement a statement interface reference.
  @param ParamName a name of the parameter.
  @param Default a parameter default value.
  @return a parameter value or default if nothing was found.
}
function DefineStatementParameter(Statement: IZStatement; const ParamName: string;
  const Default: string): string;

{**
  ToLikeString returns the given string or if the string is empty it returns '%'
  @param Value the string
  @return given Value or '%'
}
function ToLikeString(const Value: string): string;

{**
  GetSQLHexString returns a valid x'..' database understandable String from
    binary data
  @param Value the ansistring-pointer to the binary data
  @param Len then length of the binary Data
  @param ODBC a boolean if output result should be with a starting 0x...
  @returns a valid hex formated unicode-safe string
}
function GetSQLHexWideString(Value: PAnsiChar; Len: Integer; ODBC: Boolean = False): ZWideString;
function GetSQLHexAnsiString(Value: PAnsiChar; Len: Integer; ODBC: Boolean = False): RawByteString;
function GetSQLHexString(Value: PAnsiChar; Len: Integer; ODBC: Boolean = False): String;

{**
  Returns a FieldSize in Bytes dependend to the FieldType and CharWidth
  @param <code>TZSQLType</code> the Zeos FieldType
  @param <code>Integer</code> the Current given FieldLength
  @param <code>Integer</code> the Current CountOfByte/Char
  @param <code>Boolean</code> does the Driver returns the FullSizeInBytes
  @returns <code>Integer</code> the count of AnsiChars for Field.Size * SizeOf(Char)
}
function GetFieldSize(const SQLType: TZSQLType;ConSettings: PZConSettings;
  const Precision, CharWidth: Integer; DisplaySize: PInteger = nil;
    SizeInBytes: Boolean = False): Integer;

function WideStringStream(const AString: WideString): TStream;

function TokenizeSQLQueryRaw(var SQL: {$IF defined(FPC) and defined(WITH_RAWBYTESTRING)}RawByteString{$ELSE}String{$IFEND}; Const ConSettings: PZConSettings;
  const Tokenizer: IZTokenizer; var IsParamIndex, IsNCharIndex: TBooleanDynArray;
  const NeedNCharDetection: Boolean = False): TRawDynArray;
function TokenizeSQLQueryUni(var SQL: {$IF defined(FPC) and defined(WITH_RAWBYTESTRING)}RawByteString{$ELSE}String{$IFEND}; Const ConSettings: PZConSettings;
  const Tokenizer: IZTokenizer; var IsParamIndex, IsNCharIndex: TBooleanDynArray;
  const NeedNCharDetection: Boolean = False): TUnicodeDynArray;


implementation

uses ZMessages, ZSysUtils, ZEncoding, ZMatchPattern
  {$IFDEF USE_FAST_CHARPOS},ZFastCode{$ENDIF};

{**
  Resolves a connection protocol and raises an exception with protocol
  is not supported.
  @param Url an initial database URL.
  @param SupportedProtocols a driver's supported subprotocols.
}
function ResolveConnectionProtocol(Url: string;
  SupportedProtocols: TStringDynArray): string;
var
  I: Integer;
  Protocol: string;
  Index: Integer;
begin
  Result := '';

  Index := FirstDelimiter(':', Url);
  if Index > 0 then
    Protocol := Copy(Url, Index + 1, Length(Url) - Index)
  else
    Protocol := '';
  Index := FirstDelimiter(':', Protocol);
  if Index > 1 then
    Protocol := Copy(Protocol, 1, Index - 1)
  else
    Protocol := '';

  if Protocol = '' then
    raise EZSQLException.Create(Format(SIncorrectConnectionURL, [Url]));

  for I := Low(SupportedProtocols) to High(SupportedProtocols) do
  begin
    if SupportedProtocols[I] = Protocol then
    begin
      Result := Protocol;
      Break;
    end;
  end;

  if Result = '' then
    raise EZSQLException.Create(Format(SUnsupportedProtocol, [Protocol]));
end;

{**
  Resolves a database URL and fills the database connection parameters.
  @param Url an initial database URL.
  @param Info an initial info parameters.
  @param HostName a name of the database host.
  @param Port a port number.
  @param Database a database name.
  @param UserName a name of the database user.
  @param Password a user's password.
  @param ResutlInfo a result info parameters.
}
procedure ResolveDatabaseUrl(const Url: string; Info: TStrings;
  var HostName: string; var Port: Integer; var Database: string;
  var UserName: string; var Password: string; ResultInfo: TStrings);
var
  Temp: string;
begin
   { assign URL first -> define all out out params }
   {A correct builded URL exports all these Params if they are expected!}
  DriverManager.ResolveDatabaseUrl(URL, HostName, Port, DataBase, UserName, Password, ResultInfo);

  { Retrieves non special-escaped-parameters }
  Temp := Url;
  while FirstDelimiter('?', Temp) > 0 do //Get all aditional Parameters
    Temp := Copy(Temp, FirstDelimiter('?', Temp)+1, Length(Temp));
  PutSplitString(ResultInfo, Temp, ';'); //overrides all Strings
  ResultInfo.Text := StringReplace(ResultInfo.Text, #9, ';', [rfReplaceAll]); //unescape the #9 char

  if Assigned(Info) then //isn't that strange? (Shouldn't we pick out double-values?)
    Resultinfo.AddStrings(Info);//All possible PWD/Password and UID/UserName are aviable now, but for what? And the can also be doubled!

  { Redefines user name if not avialble in the URL}
  if UserName = '' then //Priority 1: URL.UserName
  begin
    UserName := ResultInfo.Values['UID']; //Priority 2: Info-UID
    if UserName = '' then
      UserName := ResultInfo.Values['username']; //Priority 3: Info-username
  end;

  { Redefines user password if not avialble in the URL }
  if Password = '' then //Priority 1: URL.Password
  begin
    Password := ResultInfo.Values['PWD']; //Priority 2: Info-PWD
    if Password = '' then
      Password := ResultInfo.Values['password']; //Priority 3: Info-password
  end;
end;

{**
  Checks is the convertion from one type to another type allowed.
  @param InitialType an initial data type.
  @param ResultType a result data type.
  @return <code>True</code> if convertion is allowed
    or <code>False</code> otherwise.
}
function CheckConvertion(InitialType: TZSQLType; ResultType: TZSQLType): Boolean;
begin
  case ResultType of
    stBoolean, stByte, stShort, stInteger,
    stLong, stFloat, stDouble, stBigDecimal:
      Result := InitialType in [stBoolean, stByte, stShort, stInteger,
        stLong, stFloat, stDouble, stBigDecimal, stString, stUnicodeString];
    stString, stUnicodeString:
      Result := True;
    stBytes:
      Result := InitialType in [stString, stUnicodeString, stBytes, stGUID,
        stAsciiStream, stUnicodeStream, stBinaryStream];
    stTimestamp:
      Result := InitialType in [stString, stUnicodeString, stDate, stTime, stTimestamp];
    stDate:
      Result := InitialType in [stString, stUnicodeString, stDate, stTimestamp];
    stTime:
      Result := InitialType in [stString, stUnicodeString, stTime, stTimestamp];
    else
      Result := (ResultType = InitialType) and (InitialType <> stUnknown);
  end;
end;

{**
  Defines a name of the column type.
  @param ColumnType a type of the column.
  @return a name of the specified type.
}
function DefineColumnTypeName(ColumnType: TZSQLType): string;
begin
  case ColumnType of
    stBoolean:
      Result := 'Boolean';
    stByte:
      Result := 'Byte';
    stShort:
      Result := 'Short';
    stInteger:
      Result := 'Integer';
    stLong:
      Result := 'Long';
    stFloat:
      Result := 'Float';
    stDouble:
      Result := 'Double';
    stBigDecimal:
      Result := 'BigDecimal';
    stString:
      Result := 'String';
    stUnicodeString:
      Result := 'UnicodeString';
    stBytes:
      Result := 'Bytes';
    stGUID:
      Result := 'GUID';
    stDate:
      Result := 'Date';
    stTime:
      Result := 'Time';
    stTimestamp:
      Result := 'Timestamp';
    stAsciiStream:
      Result := 'AsciiStream';
    stUnicodeStream:
      Result := 'UnicodeStream';
    stBinaryStream:
      Result := 'BinaryStream';
    else
      Result := 'Unknown';
  end;
end;

{**
  Raises a copy of the given exception.
  @param E an exception to be raised.
}
procedure RaiseSQLException(E: Exception);
begin
  if E is EZSQLException then
  begin
    raise EZSQLException.CreateClone(EZSQLException(E));
  end
  else
  begin
    raise EZSQLException.Create(E.Message);
  end;
end;

{**
  Copies column information objects from one object list to another one.
  @param FromList the source object list.
  @param ToList the destination object list.
}
procedure CopyColumnsInfo(FromList: TObjectList; ToList: TObjectList);
var
  I: Integer;
  Current: TZColumnInfo;
  ColumnInfo: TZColumnInfo;
begin
  for I := 0 to FromList.Count - 1 do
  begin
    Current := TZColumnInfo(FromList[I]);
    ColumnInfo := TZColumnInfo.Create;

    ColumnInfo.AutoIncrement := Current.AutoIncrement;
    ColumnInfo.CaseSensitive := Current.CaseSensitive;
    ColumnInfo.Searchable := Current.Searchable;
    ColumnInfo.Currency := Current.Currency;
    ColumnInfo.Nullable := Current.Nullable;
    ColumnInfo.Signed := Current.Signed;
    ColumnInfo.ColumnDisplaySize := Current.ColumnDisplaySize;
    ColumnInfo.ColumnLabel := Current.ColumnLabel;
    ColumnInfo.ColumnName := Current.ColumnName;
    ColumnInfo.SchemaName := Current.SchemaName;
    ColumnInfo.Precision := Current.Precision;
    ColumnInfo.Scale := Current.Scale;
    ColumnInfo.TableName := Current.TableName;
    ColumnInfo.CatalogName := Current.CatalogName;
    ColumnInfo.ColumnType := Current.ColumnType;
    ColumnInfo.ReadOnly := Current.ReadOnly;
    ColumnInfo.Writable := Current.Writable;
    ColumnInfo.DefinitelyWritable := Current.DefinitelyWritable;
    ColumnInfo.ColumnCodePage := Current.ColumnCodePage;

    ToList.Add(ColumnInfo);
  end;
end;

{**
  Defines a statement specific parameter.
  @param Statement a statement interface reference.
  @param ParamName a name of the parameter.
  @param Default a parameter default value.
  @return a parameter value or default if nothing was found.
}
function DefineStatementParameter(Statement: IZStatement; const ParamName: string;
  const Default: string): string;
begin
  Result := Statement.GetParameters.Values[ParamName];
  if Result = '' then
    Result := Statement.GetConnection.GetParameters.Values[ParamName];
  if Result = '' then
    Result := Default;
end;

{**
  ToLikeString returns the given string or if the string is empty it returns '%'
  @param Value the string
  @return given Value or '%'
}
function ToLikeString(const Value: string): string;
begin
  if Value = '' then
    Result := '%'
  else
    Result := Value;
end;

{**
  GetSQLHexString returns a valid x'..' database understandable String from
    binary data
  @param Value the ansistring-pointer to the binary data
  @param Length then length of the binary Data
  @param ODBC a boolean if output result should be with a starting 0x...
  @returns a valid hex formated unicode-safe string
}

function GetSQLHexWideString(Value: PAnsiChar; Len: Integer; ODBC: Boolean = False): ZWideString;
var P: PWideChar;
begin
  Result := ''; //init speeds setlength x2
  if ODBC then
  begin
    SetLength(Result,(Len * 2)+2);
    P := PWideChar(Result);
    P^ := '0';
    Inc(P);
    P^ := 'x';
    Inc(P);
    ZBinToHexUnicode(Value, P, Len);
  end
  else
  begin
    SetLength(Result, (Len * 2)+3);
    P := PWideChar(Result);
    P^ := 'x';
    Inc(P);
    P^ := #39;
    Inc(P);
    ZBinToHexUnicode(Value, P, Len);
    Inc(P, Len*2);
    P^ := #39;
  end;
end;

function GetSQLHexAnsiString(Value: PAnsiChar; Len: Integer; ODBC: Boolean = False): RawByteString;
var P: PAnsiChar;
begin
  Result := ''; //init speeds setlength x2
  if ODBC then
  begin
    SetLength(Result,(Len * 2)+2);
    P := PAnsiChar(Result);
    P^ := '0';
    Inc(P);
    P^ := 'x';
    Inc(P);
    ZBinToHexRaw(Value, P, Len);
  end
  else
  begin
    SetLength(Result, (Len * 2)+3);
    P := PAnsiChar(Result);
    P^ := 'x';
    Inc(P);
    P^ := #39;
    Inc(P);
    ZBinToHexRaw(Value, P, Len);
    Inc(P, Len*2);
    P^ := #39;
  end;
end;

function GetSQLHexString(Value: PAnsiChar; Len: Integer; ODBC: Boolean = False): String;
begin
  {$IFDEF UNICODE}
  Result := GetSQLHexWideString(Value, Len, ODBC);
  {$ELSE}
  Result := GetSQLHexAnsiString(Value, Len, ODBC);
  {$ENDIF}
end;

{**
  Returns a FieldSize in Bytes dependend to the FieldType and CharWidth
  @param <code>TZSQLType</code> the Zeos FieldType
  @param <code>Integer</code> the Current given FieldLength
  @param <code>Integer</code> the Current CountOfByte/Char
  @param <code>Boolean</code> does the Driver returns the FullSizeInBytes
  @returns <code>Integer</code> the count of AnsiChars for Field.Size * SizeOf(Char)
}
function GetFieldSize(const SQLType: TZSQLType; ConSettings: PZConSettings;
  const Precision, CharWidth: Integer; DisplaySize: PInteger = nil;
    SizeInBytes: Boolean = False): Integer;
var
  TempPrecision: Integer;
begin
  if ( SQLType in [stString, stUnicodeString] ) and ( Precision <> 0 )then
  begin
    if SizeInBytes then
      TempPrecision := Precision div CharWidth
    else
      TempPrecision := Precision;

    if Assigned(DisplaySize) then
      DisplaySize^ := TempPrecision;

    if SQLType = stString then
      //the RowAccessor assumes SizeOf(Char)*Precision+SizeOf(Char)
      //the Field assumes Precision*SizeOf(Char)
      {$IFDEF UNICODE}
      if ConSettings.ClientCodePage.CharWidth >= 2 then //All others > 3 are UTF8
        Result := TempPrecision * 2 //add more mem for a reserved thirt byte
      else //two and one byte AnsiChars are one WideChar
        Result := TempPrecision
      {$ELSE}
        if ( ConSettings.CPType = cCP_UTF8 ) or (ConSettings.CTRL_CP = zCP_UTF8) then
          Result := TempPrecision * 4
        else
          Result := TempPrecision * CharWidth
      {$ENDIF}
    else //stUnicodeString
      //UTF8 can pickup LittleEndian/BigEndian 4 Byte Chars
      //the RowAccessor assumes 2*Precision+2!
      //the Field assumes 2*Precision ??Does it?
      if CharWidth > 2 then
        Result := TempPrecision * 2
      else
        Result := TempPrecision;
  end
  else
    Result := Precision;
end;

function WideStringStream(const AString: WideString): TStream;
begin
  Result := TMemoryStream.Create;
  Result.Write(PWideChar(AString)^, Length(AString)*2);
  Result.Position := 0;
end;

{**
  Splits a SQL query into a list of sections.
  @returns a list of splitted sections.
}
function TokenizeSQLQueryRaw(var SQL: {$IF defined(FPC) and defined(WITH_RAWBYTESTRING)}RawByteString{$ELSE}String{$IFEND}; Const ConSettings: PZConSettings;
  const Tokenizer: IZTokenizer; var IsParamIndex, IsNCharIndex: TBooleanDynArray;
  const NeedNCharDetection: Boolean = False): TRawDynArray;
var
  I: Integer;
  Temp: RawByteString;
  NextIsNChar, ParamFound: Boolean;
  Tokens: TZTokenDynArray;

  procedure Add(const Value: RawByteString; const Param: Boolean = False);
  begin
    SetLength(Result, Length(Result)+1);
    Result[High(Result)] := Value;
    SetLength(IsParamIndex, Length(Result));
    IsParamIndex[High(IsParamIndex)] := Param;
    SetLength(IsNCharIndex, Length(Result));
    if Param and NextIsNChar then
    begin
      IsNCharIndex[High(IsNCharIndex)] := True;
      NextIsNChar := False;
    end
    else
      IsNCharIndex[High(IsNCharIndex)] := False;
  end;
begin
  ParamFound := ({$IFDEF USE_FAST_CHARPOS}ZFastCode.CharPos{$ELSe}Pos{$ENDIF}('?', SQL) > 0);
  if ParamFound or ConSettings^.AutoEncode then
  begin
    Tokens := Tokenizer.TokenizeBuffer(SQL, [toUnifyWhitespaces]);
    Temp := '';
    SQL := '';
    NextIsNChar := False;

    for I := 0 to High(Tokens) do
    begin
      SQL := SQL + Tokens[I].Value;
      if ParamFound and (Tokens[I].Value = '?') then
      begin
        Add(Temp);
        Add('?', True);
        Temp := '';
      end
      else
        if ParamFound and NeedNCharDetection and (Tokens[I].Value = 'N') and
          (Length(Tokens) > i) and (Tokens[i+1].Value = '?') then
        begin
          Add(Temp);
          Add('N');
          Temp := '';
          NextIsNChar := True;
        end
        else
          case (Tokens[i].TokenType) of
            ttEscape:
              Temp := Temp +
                {$IFDEF UNICODE}
                ConSettings^.ConvFuncs.ZStringToRaw(Tokens[i].Value,
                  ConSettings^.CTRL_CP, ConSettings^.ClientCodePage^.CP);
                {$ELSE}
                Tokens[i].Value;
                {$ENDIF}
            ttQuoted, ttComment,
            ttWord, ttQuotedIdentifier, ttKeyword:
              Temp := Temp + ConSettings^.ConvFuncs.ZStringToRaw(Tokens[i].Value, ConSettings^.CTRL_CP, ConSettings^.ClientCodePage^.CP)
            else
              Temp := Temp + {$IFDEF UNICODE}PosEmptyStringToASCII7{$ENDIF}(Tokens[i].Value);
          end;
    end;
    if (Temp <> '') then
      Add(Temp);
  end
  else
    Add(ConSettings^.ConvFuncs.ZStringToRaw(SQL, ConSettings^.CTRL_CP, ConSettings^.ClientCodePage^.CP));
end;

{**
  Splits a SQL query into a list of sections.
  @returns a list of splitted sections.
}
function TokenizeSQLQueryUni(var SQL: {$IF defined(FPC) and defined(WITH_RAWBYTESTRING)}RawByteString{$ELSE}String{$IFEND}; Const ConSettings: PZConSettings;
  const Tokenizer: IZTokenizer; var IsParamIndex, IsNCharIndex: TBooleanDynArray;
  const NeedNCharDetection: Boolean = False): TUnicodeDynArray;
var
  I: Integer;
  Tokens: TZTokenDynArray;
  Temp: ZWideString;
  NextIsNChar, ParamFound: Boolean;
  procedure Add(const Value: ZWideString; Const Param: Boolean = False);
  begin
    SetLength(Result, Length(Result)+1);
    Result[High(Result)] := Value;
    SetLength(IsParamIndex, Length(Result));
    IsParamIndex[High(IsParamIndex)] := Param;
    SetLength(IsNCharIndex, Length(Result));
    if Param and NextIsNChar then
    begin
      IsNCharIndex[High(IsNCharIndex)] := True;
      NextIsNChar := False;
    end
    else
      IsNCharIndex[High(IsNCharIndex)] := False;
  end;
begin
  ParamFound := ({$IFDEF USE_FAST_CHARPOS}ZFastCode.CharPos{$ELSe}Pos{$ENDIF}('?', SQL) > 0);
  if ParamFound or ConSettings^.AutoEncode then
  begin
    Tokens := Tokenizer.TokenizeBuffer(SQL, [toUnifyWhitespaces]);

    Temp := '';
    SQL := '';
    NextIsNChar := False;
    for I := 0 to High(Tokens) do
    begin
      SQL := SQL + Tokens[I].Value;
      if ParamFound and (Tokens[I].Value = '?') then
      begin
        Add(Temp);
        Add('?', True);
        Temp := '';
      end
      else
        if ParamFound and NeedNCharDetection and (Tokens[I].Value = 'N') and
          (Length(Tokens) > i) and (Tokens[i+1].Value = '?') then
        begin
          Add(Temp);
          Add('N');
          Temp := '';
          NextIsNChar := True;
        end
        else
          {$IFDEF UNICODE}
          Temp := Temp + Tokens[i].Value;
          {$ELSE}
          case (Tokens[i].TokenType) of
            ttEscape, ttQuoted, ttComment,
            ttWord, ttQuotedIdentifier, ttKeyword:
              Temp := Temp + ConSettings^.ConvFuncs.ZStringToUnicode(Tokens[i].Value, ConSettings^.CTRL_CP)
            else
              Temp := Temp + PosEmptyASCII7ToUnicodeString(Tokens[i].Value);
          end;
          {$ENDIF}
    end;
    if (Temp <> '') then
      Add(Temp);
  end
  else
    {$IFDEF UNICDE}
    Add(SQL);
    {$ELSE}
    Add(ConSettings^.ConvFuncs.ZStringToUnicode(SQL, ConSettings^.CTRL_CP));
    {$ENDIF}
end;

end.

