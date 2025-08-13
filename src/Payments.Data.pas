unit Payments.Data;

{$mode ObjFPC}{$H+}
{$modeswitch typehelpers}

interface

uses
  Classes,
  SysUtils;

type
  TPayment = record
    CorrelationId: String;
    Amount: Double;
  end;

  TPaymentHelper = type helper for TPayment
    class function FromJson(AContent: String): TPayment; static;
  end;

implementation

{ TPaymentHelper }

class function TPaymentHelper.FromJson(AContent: String): TPayment;
var
  Str: String;
  StartPos, EndPos: Integer;
begin
  {
      "correlationId": "4a7901b8-7d26-4d9d-aa19-4dc1c7cf60b3",
      "amount": 19.90
  }
  StartPos := Pos('"correlationId"', AContent) + 15;
  StartPos := Pos(':', AContent, StartPos) + 1;
  EndPos := Pos(',', AContent, StartPos);
  Str := Copy(AContent, StartPos, EndPos - StartPos);
  Str := Trim(Str);
  Str := Copy(Str, 2, Length(Str) - 2);

  Result.CorrelationId := Str;

  StartPos := Pos('"amount"', AContent) + 8;
  StartPos := Pos(':', AContent, StartPos) + 1;
  EndPos := Pos('}', AContent, StartPos);
  Str := Copy(AContent, StartPos, EndPos - StartPos);
  Str := Trim(Str);

  Result.Amount := Str.ToDouble;
end;

end.

