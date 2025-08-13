program Payments;

{$mode objfpc}{$H+}

{$OPTIMIZATION ON}
{$SMARTLINK ON}
{$INLINE ON}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes,
  Payments.App;

var
  App: TPaymentsApp;
begin
  App := TPaymentsApp.Create(nil);
  try
    App.Initialize;
    App.Run;
  finally
    App.Free;
  end;
end.

