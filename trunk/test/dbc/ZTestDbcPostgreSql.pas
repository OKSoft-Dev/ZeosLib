{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{ Test Case for PostgreSql Database Connectivity Classes  }
{                                                         }
{       Originally written by Sergey Seroukhov            }
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

unit ZTestDbcPostgreSql;

interface
{$I ZDbc.inc}

uses
  Classes, {$IFDEF FPC}testregistry{$ELSE}TestFramework{$ENDIF}, ZDbcIntfs, ZDbcPostgreSql, ZSqlTestCase,
  ZCompatibility;

type

  {** Implements a test case for class TZAbstractDriver and Utilities. }
  TZTestDbcPostgreSQLCase = class(TZAbstractDbcSQLTestCase)
  private
  protected
    function GetSupportedProtocols: string; override;
  published
    procedure TestConnection;
    procedure TestStatement;
    procedure TestRegularResultSet;
    procedure TestBlobs;
    procedure TestCaseSensitive;
    procedure TestDefaultValues;
    procedure TestEnumValues;
  end;

implementation

uses SysUtils, ZTestConsts;

{ TZTestDbcPostgreSQLCase }

{**
  Gets an array of protocols valid for this test.
  @return an array of valid protocols
}
function TZTestDbcPostgreSQLCase.GetSupportedProtocols: string;
begin
  Result := pl_all_postgresql;
end;

procedure TZTestDbcPostgreSQLCase.TestConnection;
begin
  CheckEquals(False, Connection.IsReadOnly);
  CheckEquals(True, Connection.IsClosed);
  CheckEquals(True, Connection.GetAutoCommit);
  CheckEquals(Ord(tiNone), Ord(Connection.GetTransactionIsolation));

  CheckEquals('inet', (Connection as IZPostgreSQLConnection).
    GetTypeNameByOid(869));

  { Checks without transactions. }
  Connection.CreateStatement;
  CheckEquals(False, Connection.IsClosed);
  Connection.Commit;
  Connection.Rollback;
  Connection.Close;
  CheckEquals(True, Connection.IsClosed);

  { Checks with transactions. }
  Connection.SetTransactionIsolation(tiSerializable);
  Connection.CreateStatement;
  CheckEquals(False, Connection.IsClosed);
  Connection.Commit;
  Connection.Rollback;
  Connection.Close;
  CheckEquals(True, Connection.IsClosed);
end;

procedure TZTestDbcPostgreSQLCase.TestStatement;
var
  Statement: IZStatement;
begin
  Statement := Connection.CreateStatement;
  CheckNotNull(Statement);

  Statement.ExecuteUpdate('UPDATE equipment SET eq_name=eq_name');
  Statement.ExecuteUpdate('SELECT * FROM equipment');

  Check(not Statement.Execute('UPDATE equipment SET eq_name=eq_name'));
  Check(Statement.Execute('SELECT * FROM equipment'));
  Statement.Close;
end;

procedure TZTestDbcPostgreSQLCase.TestRegularResultSet;
var
  Statement: IZStatement;
  ResultSet: IZResultSet;
begin
  Statement := Connection.CreateStatement;
  CheckNotNull(Statement);
  Statement.SetResultSetType(rtScrollInsensitive);
  Statement.SetResultSetConcurrency(rcReadOnly);

  ResultSet := Statement.ExecuteQuery('SELECT * FROM department');
  CheckNotNull(ResultSet);
  PrintResultSet(ResultSet, True);
  ResultSet.Close;

  ResultSet := Statement.ExecuteQuery('SELECT * FROM blob_values');
  CheckNotNull(ResultSet);
  PrintResultSet(ResultSet, True);
  ResultSet.Close;

  Statement.Close;
  Connection.Close;
end;

procedure TZTestDbcPostgreSQLCase.TestBlobs;
const
  b_id_index = {$IFDEF GENERIC_INDEX}0{$ELSE}1{$ENDIF};
  b_text_index = {$IFDEF GENERIC_INDEX}1{$ELSE}2{$ENDIF};
  b_image_index = {$IFDEF GENERIC_INDEX}2{$ELSE}3{$ENDIF};
var
  Connection: IZConnection;
  PreparedStatement: IZPreparedStatement;
  Statement: IZStatement;
  ResultSet: IZResultSet;
  TextStream: TStream;
  ImageStream: TMemoryStream;
  TempStream: TStream;
begin
  Connection := DriverManager.GetConnection(GetConnectionUrl('oidasblob=true'));
  //Connection := DriverManager.GetConnectionWithLogin(
    //GetConnectionUrl + '?oidasblob=true', UserName, Password);
  Connection.SetTransactionIsolation(tiReadCommitted);
  Statement := Connection.CreateStatement;
  CheckNotNull(Statement);
  Statement.SetResultSetType(rtScrollInsensitive);
  Statement.SetResultSetConcurrency(rcReadOnly);

  Statement.ExecuteUpdate('DELETE FROM blob_values WHERE b_id='
    + IntToStr(TEST_ROW_ID));

  TextStream := TStringStream.Create('ABCDEFG');
  ImageStream := TMemoryStream.Create;
  ImageStream.LoadFromFile('../../../database/images/zapotec.bmp');

  PreparedStatement := Connection.PrepareStatement(
    'INSERT INTO blob_values (b_id,b_text,b_image) VALUES(?,?,?)');
  PreparedStatement.SetInt(b_id_index, TEST_ROW_ID);
  PreparedStatement.SetAsciiStream(b_text_index, TextStream);
  PreparedStatement.SetBinaryStream(b_image_index, ImageStream);
  CheckEquals(1, PreparedStatement.ExecuteUpdatePrepared);

  ResultSet := Statement.ExecuteQuery('SELECT * FROM blob_values'
    + ' WHERE b_id=' + IntToStr(TEST_ROW_ID));
  CheckNotNull(ResultSet);
  Check(ResultSet.Next);
  CheckEquals(TEST_ROW_ID, ResultSet.GetIntByName('b_id'));
  TempStream := ResultSet.GetAsciiStreamByName('b_text');
  CheckEquals(TextStream, TempStream);
  TempStream.Free;
  TempStream := ResultSet.GetBinaryStreamByName('b_image');
  CheckEquals(ImageStream, TempStream);
  TempStream.Free;
  ResultSet.Close;

  TextStream.Free;
  ImageStream.Free;

  Statement.Close;
  Connection.Close;
end;

procedure TZTestDbcPostgreSQLCase.TestCaseSensitive;
const
  cs_id_index = {$IFDEF GENERIC_INDEX}0{$ELSE}1{$ENDIF};
  Cs_Data1_index = {$IFDEF GENERIC_INDEX}1{$ELSE}2{$ENDIF};
  cs_data1_2_index = {$IFDEF GENERIC_INDEX}2{$ELSE}3{$ENDIF};
  cs_data1_3_index = {$IFDEF GENERIC_INDEX}3{$ELSE}4{$ENDIF};
var
  Statement: IZStatement;
  ResultSet: IZResultSet;
  Metadata: IZResultSetMetadata;
begin
  Statement := Connection.CreateStatement;
  CheckNotNull(Statement);

  ResultSet := Statement.ExecuteQuery('SELECT * FROM "Case_Sensitive"');
  CheckNotNull(ResultSet);
  Metadata := ResultSet.GetMetadata;
  CheckNotNull(Metadata);

  CheckEquals('cs_id', Metadata.GetColumnName(cs_id_index));
  CheckEquals(False, Metadata.IsCaseSensitive(cs_id_index));
  CheckEquals('Case_Sensitive', Metadata.GetTableName(cs_id_index));

  CheckEquals('Cs_Data1', Metadata.GetColumnName(Cs_Data1_index));
  CheckEquals(True, Metadata.IsCaseSensitive(Cs_Data1_index));
  CheckEquals('Case_Sensitive', Metadata.GetTableName(Cs_Data1_index));

  CheckEquals('cs_data1', Metadata.GetColumnName(cs_data1_2_index));
  CheckEquals(False, Metadata.IsCaseSensitive(cs_data1_2_index));
  CheckEquals('Case_Sensitive', Metadata.GetTableName(cs_data1_2_index));

  CheckEquals('cs data1', Metadata.GetColumnName(cs_data1_3_index));
  CheckEquals(True, Metadata.IsCaseSensitive(cs_data1_3_index));
  CheckEquals('Case_Sensitive', Metadata.GetTableName(cs_data1_3_index));

  ResultSet.Close;
  Statement.Close;
  Connection.Close;
end;

{**
  Runs a test for PostgreSQL default values.
}
procedure TZTestDbcPostgreSQLCase.TestDefaultValues;
const
  D_ID = {$IFDEF GENERIC_INDEX}0{$ELSE}1{$ENDIF};
  D_FLD1 = {$IFDEF GENERIC_INDEX}1{$ELSE}2{$ENDIF};
  D_FLD2 = {$IFDEF GENERIC_INDEX}2{$ELSE}3{$ENDIF};
  D_FLD3 = {$IFDEF GENERIC_INDEX}3{$ELSE}4{$ENDIF};
  D_FLD4 = {$IFDEF GENERIC_INDEX}4{$ELSE}5{$ENDIF};
  D_FLD5 = {$IFDEF GENERIC_INDEX}5{$ELSE}6{$ENDIF};
  D_FLD6 = {$IFDEF GENERIC_INDEX}6{$ELSE}7{$ENDIF};
var
  Statement: IZStatement;
  ResultSet: IZResultSet;
begin
  Statement := Connection.CreateStatement;
  CheckNotNull(Statement);
  Statement.SetResultSetType(rtScrollInsensitive);
  Statement.SetResultSetConcurrency(rcUpdatable);

  Statement.ExecuteUpdate('delete from default_values');

  ResultSet := Statement.ExecuteQuery('SELECT d_id,d_fld1,d_fld2,d_fld3,d_fld4,d_fld5,d_fld6 FROM default_values');
  CheckNotNull(ResultSet);

  ResultSet.MoveToInsertRow;
  ResultSet.InsertRow;

  Check(ResultSet.GetInt(D_ID) <> 0);
  CheckEquals(123456, ResultSet.GetInt(D_FLD1));
  CheckEquals(123.456, ResultSet.GetFloat(D_FLD2), 0.001);
  CheckEquals('xyz', ResultSet.GetString(D_FLD3));
  CheckEquals(EncodeDate(2003, 12, 11), ResultSet.GetDate(D_FLD4), 0);
  CheckEquals(EncodeTime(23, 12, 11, 0), ResultSet.GetTime(D_FLD5), 3);
  CheckEquals(EncodeDate(2003, 12, 11) +
    EncodeTime(23, 12, 11, 0), ResultSet.GetTimestamp(D_FLD6), 3);

  ResultSet.DeleteRow;

  ResultSet.Close;
  Statement.Close;
end;

procedure TZTestDbcPostgreSQLCase.TestEnumValues;
const
  ext_id_index = {$IFDEF GENERIC_INDEX}0{$ELSE}1{$ENDIF};
  ext_enum_index = {$IFDEF GENERIC_INDEX}1{$ELSE}2{$ENDIF};
var
  Statement: IZStatement;
  ResultSet: IZResultSet;
begin
  Statement := Connection.CreateStatement;
  CheckNotNull(Statement);
  Statement.SetResultSetType(rtScrollInsensitive);
  Statement.SetResultSetConcurrency(rcUpdatable);

  // Select case
  ResultSet := Statement.ExecuteQuery('SELECT * FROM extension where ext_id = 1');
  CheckNotNull(ResultSet);
  ResultSet.First;
  Check(ResultSet.GetInt(ext_id_index) = 1);
  CheckEquals('Car', ResultSet.GetString(ext_enum_index));
  ResultSet.Close;
  Statement.Close;

  // Update case
  ResultSet := Statement.ExecuteQuery('UPDATE extension set ext_enum = ''House'' where ext_id = 1');
  ResultSet.Close;

  ResultSet := Statement.ExecuteQuery('SELECT * FROM extension where ext_id = 1');
  CheckNotNull(ResultSet);
  ResultSet.First;
  Check(ResultSet.GetInt(ext_id_index) = 1);
  CheckEquals('House', ResultSet.GetString(ext_enum_index));
  ResultSet.Close;
  Statement.Close;

  // Insert case
  ResultSet := Statement.ExecuteQuery('DELETE FROM extension where ext_id = 1');
  ResultSet.Close;

  ResultSet := Statement.ExecuteQuery('INSERT INTO extension VALUES(1,''Car'')');
  ResultSet.Close;

  ResultSet := Statement.ExecuteQuery('SELECT * FROM extension where ext_id = 1');
  CheckNotNull(ResultSet);
  ResultSet.First;
  Check(ResultSet.GetInt(ext_id_index) = 1);
  CheckEquals('Car', ResultSet.GetString(ext_enum_index));
  ResultSet.Close;
  Statement.Close;
end;

initialization
  RegisterTest('dbc',TZTestDbcPostgreSQLCase.Suite);
end.
