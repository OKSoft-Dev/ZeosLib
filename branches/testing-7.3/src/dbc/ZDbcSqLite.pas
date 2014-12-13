{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{           SQLite Database Connectivity Classes          }
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

unit ZDbcSqLite;

interface

{$I ZDbc.inc}

uses
  Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} SysUtils,
  ZDbcIntfs, ZDbcConnection, ZPlainSqLiteDriver, ZDbcLogging, ZTokenizer,
  ZGenericSqlAnalyser, ZURL, ZCompatibility;

type

  {** Implements SQLite Database Driver. }
  {$WARNINGS OFF}
  TZSQLiteDriver = class(TZAbstractDriver)
  public
    constructor Create; override;
    function Connect(const Url: TZURL): IZConnection; override;
    function GetMajorVersion: Integer; override;
    function GetMinorVersion: Integer; override;

    function GetTokenizer: IZTokenizer; override;
    function GetStatementAnalyser: IZStatementAnalyser; override;
  end;
  {$WARNINGS ON}

  {** Represents a SQLite specific connection interface. }
  IZSQLiteConnection = interface (IZConnection)
    ['{A4B797A9-7CF7-4DE9-A5BB-693DD32D07D2}']
    function GetPlainDriver: IZSQLitePlainDriver;
    function GetConnectionHandle: Psqlite;
    function GetUndefinedVarcharAsStringLength: Integer;
  end;

  {** Implements SQLite Database Connection. }

  { TZSQLiteConnection }

  TZSQLiteConnection = class(TZAbstractConnection, IZSQLiteConnection)
  private
    FCatalog: string;
    FHandle: Psqlite;
  protected
    procedure InternalCreate; override;
    procedure StartTransactionSupport;
    function GetUndefinedVarcharAsStringLength: Integer;
  public
    function CreateRegularStatement(Info: TStrings): IZStatement; override;
    function CreatePreparedStatement(const SQL: string; Info: TStrings):
      IZPreparedStatement; override;

    procedure Commit; override;
    procedure Rollback; override;

    procedure Open; override;
    procedure Close; override;

    procedure SetCatalog(const Catalog: string); override;
    function GetCatalog: string; override;

    procedure SetTransactionIsolation(Level: TZTransactIsolationLevel); override;

    function GetClientVersion: Integer; override;
    function GetHostVersion: Integer; override;

    function GetPlainDriver: IZSQLitePlainDriver;
    function GetConnectionHandle: Psqlite;

    function ReKey(const Key: string): Integer;
    function Key(const Key: string): Integer;
  end;

var
  {** The common driver manager object. }
  SQLiteDriver: IZDriver;

implementation

uses
  ZSysUtils, ZDbcSqLiteStatement, ZSqLiteToken, ZFastCode,
  ZDbcSqLiteUtils, ZDbcSqLiteMetadata, ZSqLiteAnalyser
  {$IFDEF WITH_UNITANSISTRINGS}, AnsiStrings{$ENDIF};

{ TZSQLiteDriver }

{**
  Constructs this object with default properties.
}
constructor TZSQLiteDriver.Create;
begin
  inherited Create;
  AddSupportedProtocol(AddPlainDriverToCache(TZSQLite3PlainDriver.Create, 'sqlite'));
  AddSupportedProtocol(AddPlainDriverToCache(TZSQLite3PlainDriver.Create));
end;

{**
  Attempts to make a database connection to the given URL.
  The driver should return "null" if it realizes it is the wrong kind
  of driver to connect to the given URL.  This will be common, as when
  the JDBC driver manager is asked to connect to a given URL it passes
  the URL to each loaded driver in turn.

  <P>The driver should raise a SQLException if it is the right
  driver to connect to the given URL, but has trouble connecting to
  the database.

  <P>The java.util.Properties argument can be used to passed arbitrary
  string tag/value pairs as connection arguments.
  Normally at least "user" and "password" properties should be
  included in the Properties.

  @param url the URL of the database to which to connect
  @param info a list of arbitrary string tag/value pairs as
    connection arguments. Normally at least a "user" and
    "password" property should be included.
  @return a <code>Connection</code> object that represents a
    connection to the URL
}
{$WARNINGS OFF}
function TZSQLiteDriver.Connect(const Url: TZURL): IZConnection;
begin
  Result := TZSQLiteConnection.Create(Url);
end;
{$WARNINGS ON}

{**
  Gets the driver's major version number. Initially this should be 1.
  @return this driver's major version number
}
function TZSQLiteDriver.GetMajorVersion: Integer;
begin
  Result := 1;
end;

{**
  Gets the driver's minor version number. Initially this should be 0.
  @return this driver's minor version number
}
function TZSQLiteDriver.GetMinorVersion: Integer;
begin
  Result := 0;
end;

{**
  Gets a SQL syntax tokenizer.
  @returns a SQL syntax tokenizer object.
}
function TZSQLiteDriver.GetTokenizer: IZTokenizer;
begin
  Result := TZSQLiteTokenizer.Create; { thread save! Allways return a new Tokenizer! }
end;

{**
  Creates a statement analyser object.
  @returns a statement analyser object.
}
function TZSQLiteDriver.GetStatementAnalyser: IZStatementAnalyser;
begin
  Result := TZSQLiteStatementAnalyser.Create; { thread save! Allways return a new Analyser! }
end;

{ TZSQLiteConnection }

{**
  Constructs this object and assignes the main properties.
}
procedure TZSQLiteConnection.InternalCreate;
begin
  FMetadata := TZSQLiteDatabaseMetadata.Create(Self, Url);
  AutoCommit := True;
  TransactIsolationLevel := tiNone;
  CheckCharEncoding('UTF-8');
  FUndefinedVarcharAsStringLength := StrToIntDef(Info.Values['Undefined_Varchar_AsString_Length'], 0);
  Open;
end;

{**
  Set encryption key for a database
  @param Key the key used to encrypt your database.
  @return error code from SQLite Key function.
}
function TZSQLiteConnection.Key(const Key: string):Integer;
var
  ErrorCode: Integer;
begin
  {$IFDEF UNICODE}
  ErrorCode := GetPlainDriver.Key(FHandle, PAnsiChar(UTF8String(Key)), ZFastCode.StrLen(PAnsiChar(UTF8String(Key))));
  {$ELSE}
  ErrorCode := GetPlainDriver.Key(FHandle, PAnsiChar(Key), ZFastCode.StrLen(PAnsiChar(Key)));
  {$ENDIF}
  Result := ErrorCode;
end;

{**
  Reencrypt a database with a new key. The old/current key needs to be
  set before calling this function.
  @param Key the new key used to encrypt your database.
  @return error code from SQLite ReKey function.
}
function TZSQLiteConnection.ReKey(const Key: string):Integer;
var
  ErrorCode: Integer;
begin
  {$IFDEF UNICODE}
  ErrorCode := GetPlainDriver.ReKey(FHandle, PAnsiChar(UTF8String(Key)), ZFastCode.StrLen(PAnsiChar(UTF8String(Key))));
  {$ELSE}
  ErrorCode := GetPlainDriver.ReKey(FHandle, PAnsiChar(Key), ZFastCode.StrLen(PAnsiChar(Key)));
  {$ENDIF}
  Result := ErrorCode;
end;

{**
  Opens a connection to database server with specified parameters.
}
procedure TZSQLiteConnection.Open;
var
  ErrorCode: Integer;
  ErrorMessage: PAnsiChar;
  LogMessage: RawByteString;
  SQL: RawByteString;
  TmpInt: Integer;
begin
  if not Closed then
    Exit;
  ErrorMessage := '';

  LogMessage := 'CONNECT TO "'+ConSettings^.Database+'" AS USER "'+ConSettings^.User+'"';

  SQL := {$IFDEF UNICODE}UTF8String{$ENDIF}(Database);
  FHandle := GetPlainDriver.Open(Pointer(SQL), 0, ErrorMessage);

  if FHandle = nil then
    CheckSQLiteError(GetPlainDriver, FHandle, SQLITE_ERROR, ErrorMessage,
      lcConnect, LogMessage, ConSettings);
  DriverManager.LogMessage(lcConnect, ConSettings^.Protocol, LogMessage);

  { Turn on encryption if requested }
  if StrToBoolEx(Info.Values['encrypted']) then
  begin
    SQL := {$IFDEF UNICODE}UTF8String{$ENDIF}(Password);
    ErrorCode := GetPlainDriver.Key(FHandle, Pointer(SQL), Length(SQL));
    CheckSQLiteError(GetPlainDriver, FHandle, ErrorCode, nil, lcConnect, 'SQLite.Key', ConSettings);
  end;

  { Set busy timeout if requested }
  TmpInt := StrToIntDef(Info.Values['busytimeout'], -1);
  if TmpInt >= 0 then
    GetPlainDriver.BusyTimeout(FHandle, TmpInt);

  { pimp performance }
  SQL := 'PRAGMA cache_size = '+IntToRaw(StrToIntDef(Info.Values['cache_size'], 10000));
  ErrorCode := GetPlainDriver.Execute(FHandle, Pointer(SQL), nil, nil, ErrorMessage);
  CheckSQLiteError(GetPlainDriver, FHandle, ErrorCode, ErrorMessage, lcExecute, SQL, ConSettings);

  if Info.Values['synchronous'] <> '' then //see http://www.sqlite.org/pragma.html#pragma_synchronous
  begin  //0 brings best performance
    SQL := 'PRAGMA synchronous = '+{$IFDEF UNICODE}UnicodeStringToAscii7{$ENDIF}(Info.Values['synchronous']);
    ErrorCode := GetPlainDriver.Execute(FHandle, Pointer(SQL), nil, nil, ErrorMessage);
    CheckSQLiteError(GetPlainDriver, FHandle, ErrorCode, ErrorMessage, lcExecute, SQL, ConSettings);
  end;

  if Info.Values['locking_mode'] <> '' then //see http://www.sqlite.org/pragma.html#pragma_locking_mode
  begin //EXCLUSIVE brings best performance
    SQL := 'PRAGMA locking_mode = '+{$IFDEF UNICODE}UnicodeStringToAscii7{$ENDIF}(Info.Values['locking_mode']);
    ErrorCode := GetPlainDriver.Execute(FHandle, Pointer(SQL), nil, nil, ErrorMessage);
    CheckSQLiteError(GetPlainDriver, FHandle, ErrorCode, ErrorMessage, lcExecute, SQL, ConSettings);
  end;

  try
    if ( FClientCodePage <> '' ) then
    begin
      SQL := 'PRAGMA encoding = '''+{$IFDEF UNICODE}UnicodeStringToAscii7{$ENDIF}(FClientCodePage)+'''';
      ErrorCode := GetPlainDriver.Execute(FHandle, Pointer(SQL), nil, nil, ErrorMessage);
      CheckSQLiteError(GetPlainDriver, FHandle, ErrorCode, ErrorMessage, lcExecute, SQL, ConSettings);
    end;

    SQL := 'PRAGMA show_datatypes = ON';
    ErrorCode := GetPlainDriver.Execute(FHandle, Pointer(SQL), nil, nil, ErrorMessage);
    CheckSQLiteError(GetPlainDriver, FHandle, ErrorCode, ErrorMessage, lcExecute, SQL, ConSettings);

    if Info.Values['foreign_keys'] <> '' then
    begin
      if StrToBoolEx(Info.Values['foreign_keys']) then
        SQL := 'PRAGMA foreign_keys = 1'
      else
        SQL := 'PRAGMA foreign_keys = 0';
      ErrorCode := GetPlainDriver.Execute(FHandle, Pointer(SQL), nil, nil, ErrorMessage);
      CheckSQLiteError(GetPlainDriver, FHandle, ErrorCode, ErrorMessage, lcExecute, SQL, ConSettings);
      DriverManager.LogMessage(lcConnect, ConSettings^.Protocol, SQL);
    end;
    StartTransactionSupport;
  except
    GetPlainDriver.Close(FHandle);
    FHandle := nil;
    raise;
  end;

  inherited Open;
end;

{**
  Creates a <code>Statement</code> object for sending
  SQL statements to the database.
  SQL statements without parameters are normally
  executed using Statement objects. If the same SQL statement
  is executed many times, it is more efficient to use a
  <code>PreparedStatement</code> object.
  <P>
  Result sets created using the returned <code>Statement</code>
  object will by default have forward-only type and read-only concurrency.

  @param Info a statement parameters.
  @return a new Statement object
}
function TZSQLiteConnection.CreateRegularStatement(Info: TStrings):
  IZStatement;
begin
  if IsClosed then
    Open;

  Result := TZSQLiteStatement.Create(GetPlainDriver, Self, Info, FHandle);
end;

{**
  Creates a <code>PreparedStatement</code> object for sending
  parameterized SQL statements to the database.

  A SQL statement with or without IN parameters can be
  pre-compiled and stored in a PreparedStatement object. This
  object can then be used to efficiently execute this statement
  multiple times.

  <P><B>Note:</B> This method is optimized for handling
  parametric SQL statements that benefit from precompilation. If
  the driver supports precompilation,
  the method <code>prepareStatement</code> will send
  the statement to the database for precompilation. Some drivers
  may not support precompilation. In this case, the statement may
  not be sent to the database until the <code>PreparedStatement</code> is
  executed.  This has no direct effect on users; however, it does
  affect which method throws certain SQLExceptions.

  Result sets created using the returned PreparedStatement will have
  forward-only type and read-only concurrency, by default.

  @param sql a SQL statement that may contain one or more '?' IN
    parameter placeholders
  @param Info a statement parameters.
  @return a new PreparedStatement object containing the
    pre-compiled statement
}
function TZSQLiteConnection.CreatePreparedStatement(const SQL: string;
  Info: TStrings): IZPreparedStatement;
begin
  if IsClosed then
    Open;
  Result := TZSQLiteCAPIPreparedStatement.Create(GetPlainDriver, Self, SQL, Info, FHandle);
end;

{**
  Starts a transaction support.
}
procedure TZSQLiteConnection.StartTransactionSupport;
var
  ErrorCode: Integer;
  ErrorMessage: PAnsiChar;
  SQL: RawByteString;
begin
  if TransactIsolationLevel <> tiNone then
  begin
    ErrorMessage := '';
    SQL := 'BEGIN TRANSACTION';
    ErrorCode := GetPlainDriver.Execute(FHandle, Pointer(SQL), nil, nil, ErrorMessage);
    CheckSQLiteError(GetPlainDriver, FHandle, ErrorCode, ErrorMessage, lcExecute, SQL, ConSettings);
    if Assigned(DriverManager) and DriverManager.HasLoggingListener then
      DriverManager.LogMessage(lcTransaction, ConSettings^.Protocol, SQL);
  end;
end;

function TZSQLiteConnection.GetUndefinedVarcharAsStringLength: Integer;
begin
  Result := FUndefinedVarcharAsStringLength;
end;

{**
  Makes all changes made since the previous
  commit/rollback permanent and releases any database locks
  currently held by the Connection. This method should be
  used only when auto-commit mode has been disabled.
  @see #setAutoCommit
}
procedure TZSQLiteConnection.Commit;
var
  ErrorCode: Integer;
  ErrorMessage: PAnsiChar;
  SQL: RawByteString;
begin
  if (TransactIsolationLevel <> tiNone) and not Closed then
  begin
    ErrorMessage := '';
    SQL := 'COMMIT TRANSACTION';
    ErrorCode := GetPlainDriver.Execute(FHandle, Pointer(SQL), nil, nil, ErrorMessage);
    CheckSQLiteError(GetPlainDriver, FHandle, ErrorCode, ErrorMessage, lcExecute, SQL, ConSettings);
    if Assigned(DriverManager) and DriverManager.HasLoggingListener then
      DriverManager.LogMessage(lcTransaction, ConSettings^.Protocol, SQL);

    StartTransactionSupport;
  end;
end;

{**
  Drops all changes made since the previous
  commit/rollback and releases any database locks currently held
  by this Connection. This method should be used only when auto-
  commit has been disabled.
  @see #setAutoCommit
}
procedure TZSQLiteConnection.Rollback;
var
  ErrorCode: Integer;
  ErrorMessage: PAnsiChar;
  SQL: RawByteString;
begin
  if (TransactIsolationLevel <> tiNone) and not Closed then
  begin
    ErrorMessage := '';
    SQL := 'ROLLBACK TRANSACTION';
    ErrorCode := GetPlainDriver.Execute(FHandle, Pointer(SQL), nil, nil, ErrorMessage);
    CheckSQLiteError(GetPlainDriver, FHandle, ErrorCode, ErrorMessage, lcExecute, SQL, ConSettings);
    if Assigned(DriverManager) and DriverManager.HasLoggingListener then //thread save
      DriverManager.LogMessage(lcTransaction, ConSettings^.Protocol, SQL);

    StartTransactionSupport;
  end;
end;

{**
  Releases a Connection's database and JDBC resources
  immediately instead of waiting for
  them to be automatically released.

  <P><B>Note:</B> A Connection is automatically closed when it is
  garbage collected. Certain fatal errors also result in a closed
  Connection.
}
procedure TZSQLiteConnection.Close;
var
  LogMessage: RawByteString;
  ErrorCode: Integer;
begin
  if ( Closed ) or (not Assigned(PlainDriver)) then
    Exit;

  LogMessage := 'DISCONNECT FROM "'+ConSettings^.Database+'"';
  ErrorCode := GetPlainDriver.Close(FHandle);
  CheckSQLiteError(GetPlainDriver, FHandle, ErrorCode, nil,
    lcOther, LogMessage, ConSettings);
  FHandle := nil;
  if Assigned(DriverManager) and DriverManager.HasLoggingListener then //thread save
    DriverManager.LogMessage(lcDisconnect, ConSettings^.Protocol, LogMessage);
  inherited Close;
end;

{**
  Gets a selected catalog name.
  @return a selected catalog name.
}
function TZSQLiteConnection.GetCatalog: string;
begin
  Result := FCatalog;
end;

function TZSQLiteConnection.GetClientVersion: Integer;
begin
  Result := ConvertSQLiteVersionToSQLVersion(GetPlainDriver.LibVersion);
end;

{**
  Sets a new selected catalog name.
  @param Catalog a selected catalog name.
}
procedure TZSQLiteConnection.SetCatalog(const Catalog: string);
begin
  FCatalog := Catalog;
end;

{**
  Sets a new transact isolation level.
  @param Level a new transact isolation level.
}
procedure TZSQLiteConnection.SetTransactionIsolation(
  Level: TZTransactIsolationLevel);
var
  ErrorCode: Integer;
  ErrorMessage: PAnsiChar;
  SQL: RawByteString;
begin
  if (TransactIsolationLevel <> tiNone) and not Closed then
  begin
    ErrorMessage := '';
    SQL := 'ROLLBACK TRANSACTION';
    ErrorCode := GetPlainDriver.Execute(FHandle, Pointer(SQL), nil, nil, ErrorMessage);
    CheckSQLiteError(GetPlainDriver, FHandle, ErrorCode, ErrorMessage, lcExecute, SQL, ConSettings);
    DriverManager.LogMessage(lcExecute, ConSettings^.Protocol, SQL);
  end;

  inherited SetTransactionIsolation(Level);

  if not Closed then
    StartTransactionSupport;
end;

{**
  Gets a reference to SQLite connection handle.
  @return a reference to SQLite connection handle.
}
function TZSQLiteConnection.GetConnectionHandle: Psqlite;
begin
  Result := FHandle;
end;

{**
  Gets a SQLite plain driver interface.
  @return a SQLite plain driver interface.
}
function TZSQLiteConnection.GetPlainDriver: IZSQLitePlainDriver;
begin
  Result := PlainDriver as IZSQLitePlainDriver;
end;

function TZSQLiteConnection.GetHostVersion: Integer;
begin
  Result := ConvertSQLiteVersionToSQLVersion(GetPlainDriver.LibVersion);
end;

initialization
  SQLiteDriver := TZSQLiteDriver.Create;
  DriverManager.RegisterDriver(SQLiteDriver);
finalization
  if DriverManager <> nil then
    DriverManager.DeregisterDriver(SQLiteDriver);
  SQLiteDriver := nil;
end.
