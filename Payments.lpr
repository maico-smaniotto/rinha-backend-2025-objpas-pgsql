program Payments;

{$mode objfpc}{$H+}

{$OPTIMIZATION ON}
{$SMARTLINK ON}
{$INLINE ON}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
  Classes,
  Payments.App;

var
  App: TPaymentsApp;
begin
  try
    App := TPaymentsApp.Create(nil);
    try
      App.Initialize;
      App.Run;
    finally
      App.Free;
    end;
  except
    on E: Exception do
      WriteLn(E.Message);
  end;
end.

