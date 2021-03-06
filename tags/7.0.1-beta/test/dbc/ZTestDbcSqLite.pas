{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{   Test Case for SQLite Database Connectivity Classes    }
{                                                         }
{          Originally written by Sergey Seroukhov         }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2006 Zeos Development Group       }
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
{   http://zeosbugs.firmos.at (BUGTRACKER)                }
{   svn://zeos.firmos.at/zeos/trunk (SVN Repository)      }
{                                                         }
{   http://www.sourceforge.net/projects/zeoslib.          }
{   http://www.zeoslib.sourceforge.net                    }
{                                                         }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZTestDbcSqLite;

interface

{$I ZDbc.inc}

uses
{$IFNDEF VER130BELOW}
  Types,
{$ENDIF}
  Classes, SysUtils, {$IFDEF FPC}testregistry{$ELSE}TestFramework{$ENDIF}, ZDbcIntfs, ZTestDefinitions, ZDbcSQLite,
  ZCompatibility;

type

  {** Implements a test case for class TZAbstractDriver and Utilities. }
  TZTestDbcSQLiteCase = class(TZDbcSpecificSQLTestCase)
  private
    FConnection: IZConnection;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
    function GetSupportedProtocols: string; override;

    property Connection: IZConnection read FConnection write FConnection;

  published
    procedure TestConnection;
    procedure TestStatement;
    procedure TestResultSet;
    procedure TestPreparedStatement;
    procedure TestAutoIncFields;
    procedure TestDefaultValues;
    procedure TestEmptyTypes;
  end;


implementation

uses ZSysUtils, ZTestConsts;

{ TZTestDbcSQLiteCase }

{**
  Gets an array of protocols valid for this test.
  @return an array of valid protocols
}
function TZTestDbcSQLiteCase.GetSupportedProtocols: string;
begin
  Result := 'sqlite,sqlite-3';
end;

{**
   Create objects and allocate memory for variables
}
procedure TZTestDbcSQLiteCase.SetUp;
begin
  Connection := CreateDbcConnection;
end;

{**
   Destroy objects and free allocated memory for variables
}
procedure TZTestDbcSQLiteCase.TearDown;
begin
  Connection.Close;
  Connection := nil;
end;

{**
  Runs a test for SQLite database connection.
}
procedure TZTestDbcSQLiteCase.TestConnection;
begin
  CheckEquals(True, Connection.IsReadOnly);
//  CheckEquals(True, Connection.IsClosed);
  CheckEquals(True, Connection.GetAutoCommit);
  CheckEquals(Ord(tiNone), Ord(Connection.GetTransactionIsolation));

  { Checks without transactions. }
  Connection.CreateStatement;
  CheckEquals(False, Connection.IsClosed);
//  Connection.Commit;
//  Connection.Rollback;
  Connection.Close;
  CheckEquals(True, Connection.IsClosed);

  { Checks with transactions. }
  Connection.SetTransactionIsolation(tiReadCommitted);
  Connection.CreateStatement;
  CheckEquals(False, Connection.IsClosed);
  Connection.Commit;
  Connection.Rollback;
  Connection.Close;
  CheckEquals(True, Connection.IsClosed);
end;

{**
  Runs a test for regular SQLite DBC Statement.
}
procedure TZTestDbcSQLiteCase.TestStatement;
var
  Statement: IZStatement;
begin
  Statement := Connection.CreateStatement;
  CheckNotNull(Statement);

  Statement.ExecuteUpdate('UPDATE equipment SET eq_name=eq_name');
  Statement.ExecuteUpdate('SELECT * FROM equipment');

  Check(not Statement.Execute('UPDATE equipment SET eq_name=eq_name'));
  Check(Statement.Execute('SELECT * FROM equipment WHERE 1=0'));
  Statement.Close;
end;

{**
  Runs a test for SQLite DBC ResultSet with stored results.
}
procedure TZTestDbcSQLiteCase.TestResultSet;
var
  Statement: IZStatement;
  ResultSet: IZResultSet;
  Metadata: IZDatabaseMetadata;
  TableTypes: TStringDynArray;
begin
  Statement := Connection.CreateStatement;
  CheckNotNull(Statement);
  Statement.SetResultSetType(rtScrollInsensitive);
  Statement.SetResultSetConcurrency(rcReadOnly);

  Metadata := Connection.GetMetadata;
  ResultSet := Metadata.GetBestRowIdentifier('', '', 'people', 0, False);
  CheckNotNull(ResultSet);
  PrintResultSet(ResultSet, True);
  ResultSet.Close;

  SetLength(TableTypes, 2);
  TableTypes[0] := 'TABLE';
  TableTypes[1] := 'VIEW';
  ResultSet := Metadata.GetTables('', '', '', TableTypes);
  CheckNotNull(ResultSet);
  PrintResultSet(ResultSet, True);
  ResultSet.Close;

  with Metadata.GetTables('', '', '', TableTypes) do
  try
    while Next do
      if GetString(2) = '' then
        PrintLn('Table=' + GetString(3))
      else
        PrintLn('Table=' + GetString(2) + '.' + GetString(3));
  finally
    Close;
  end;

  ResultSet := Statement.ExecuteQuery('SELECT * FROM department');
  CheckNotNull(ResultSet);
  PrintResultSet(ResultSet, True);
  ResultSet.Close;

  Statement.Close;
  Connection.Close;
end;

{**
  Runs a test for SQLite DBC PreparedStatement.
}
procedure TZTestDbcSQLiteCase.TestPreparedStatement;
var
  Statement: IZPreparedStatement;
  Stream: TStream;
begin
  Statement := Connection.PrepareStatement(
    'INSERT INTO department(dep_id,dep_name,dep_shname,dep_address)'
    + ' VALUES(?,?,?,?)');
  CheckNotNull(Statement);

  Statement.SetInt(1, TEST_ROW_ID);
  Statement.SetString(2, 'xyz');
  Statement.SetNull(3, stString);
  Stream := TStringStream.Create('abc'#10'def'#13'hg''i');
  try
    Statement.SetAsciiStream(4, Stream);
  finally
    Stream.Free;
  end;
  CheckEquals(False, Statement.ExecutePrepared);
  CheckEquals(1, Statement.GetUpdateCount);

  Statement := Connection.PrepareStatement(
    'DELETE FROM department WHERE dep_id=?');
  CheckNotNull(Statement);

  Statement.SetInt(1, TEST_ROW_ID);
  CheckEquals(1, Statement.ExecuteUpdatePrepared);
  Statement.ExecutePrepared;
  CheckEquals(0, Statement.GetUpdateCount);
end;

{**
  Runs a test for SQLite AutoIncremented fields.
}
procedure TZTestDbcSQLiteCase.TestAutoIncFields;
var
  Statement: IZStatement;
  ResultSet: IZResultSet;
begin
  Statement := Connection.CreateStatement;
  CheckNotNull(Statement);
  Statement.SetResultSetType(rtScrollInsensitive);
  Statement.SetResultSetConcurrency(rcUpdatable);

  ResultSet := Statement.ExecuteQuery('SELECT c_id, c_name FROM cargo');
  CheckNotNull(ResultSet);

  ResultSet.MoveToInsertRow;
  ResultSet.UpdateString(2, 'xxx');
  CheckEquals(0, ResultSet.GetInt(1));
  CheckEquals('xxx', ResultSet.GetString(2));

  ResultSet.InsertRow;
  Check(ResultSet.GetInt(1) <> 0);
  CheckEquals('xxx', ResultSet.GetString(2));

  ResultSet.DeleteRow;

  ResultSet.Close;

  Statement.Close;
end;

{**
  Runs a test for SQLite default values.
}
procedure TZTestDbcSQLiteCase.TestDefaultValues;
var
  Statement: IZStatement;
  ResultSet: IZResultSet;
begin
  Statement := Connection.CreateStatement;
  CheckNotNull(Statement);
  Statement.SetResultSetType(rtScrollInsensitive);
  Statement.SetResultSetConcurrency(rcUpdatable);

  Statement.Execute('delete from default_values');

  ResultSet := Statement.ExecuteQuery('SELECT d_id,d_fld1,d_fld2,d_fld3,d_fld4,d_fld5,d_fld6 FROM default_values');
  CheckNotNull(ResultSet);

  ResultSet.MoveToInsertRow;
  ResultSet.UpdateInt(1, 1);
  ResultSet.InsertRow;

  Check(ResultSet.GetInt(1) <> 0);
  CheckEquals(123456, ResultSet.GetInt(2));
  CheckEquals(123.456, ResultSet.GetFloat(3), 0.001);
  CheckEquals('xyz', ResultSet.GetString(4));
  CheckEquals(EncodeDate(2003, 12, 11), ResultSet.GetDate(5), 0);
  CheckEquals(EncodeTime(23, 12, 11, 0), ResultSet.GetTime(6), 3);
  CheckEquals(EncodeDate(2003, 12, 11) +
    EncodeTime(23, 12, 11, 0), ResultSet.GetTimestamp(7), 3);

  ResultSet.DeleteRow;

  ResultSet.Close;
  Statement.Close;
end;

{**
  Runs a test for SQLite empty types.
}
procedure TZTestDbcSQLiteCase.TestEmptyTypes;
var
  PreparedStatement: IZPreparedStatement;
  Statement: IZStatement;
  ResultSet: IZResultSet;
begin
  Statement := Connection.CreateStatement;
  CheckNotNull(Statement);

  Statement.Execute('delete from empty_types');

  PreparedStatement := Connection.PrepareStatement(
    'INSERT INTO empty_types(et_id, data1, data2) VALUES(?,?,?)');
  CheckNotNull(PreparedStatement);

  PreparedStatement.SetInt(1, 0);
  PreparedStatement.SetInt(2, 1);
  PreparedStatement.SetString(3, 'xyz');
  PreparedStatement.ExecuteUpdatePrepared;
  PreparedStatement.SetString(1, 'qwe');
  PreparedStatement.SetString(2, 'asd');
  PreparedStatement.SetString(3, 'xyzz');
  PreparedStatement.ExecuteUpdatePrepared;
  PreparedStatement.SetFloat(1, 1.25);
  PreparedStatement.SetFloat(2, 2.25);
  PreparedStatement.SetString(3, 'xyzzz');
  PreparedStatement.ExecuteUpdatePrepared;

  ResultSet := Statement.ExecuteQuery('SELECT et_id,data1,data2 FROM empty_types where data2=''xyz''');
  CheckNotNull(ResultSet);

  ResultSet.Next;
  CheckEquals(0, ResultSet.GetInt(1));
  CheckEquals(1, ResultSet.GetInt(2));

  ResultSet := Statement.ExecuteQuery('SELECT et_id,data1,data2 FROM empty_types where data2="xyzz"');
  CheckNotNull(ResultSet);

  ResultSet.Next;
  CheckEquals('qwe', ResultSet.GetString(1));
  CheckEquals('asd', ResultSet.GetString(2));

  ResultSet := Statement.ExecuteQuery('SELECT et_id,data1,data2 FROM empty_types where data2=''xyzzz''');
  CheckNotNull(ResultSet);

  ResultSet.Next;
  CheckEquals(1.25, ResultSet.GetFloat(1));
  CheckEquals(2.25, ResultSet.GetFloat(2));

  ResultSet.Close;
  Statement.Close;
end;

initialization
  RegisterTest('dbc',TZTestDbcSQLiteCase.Suite);
end.
