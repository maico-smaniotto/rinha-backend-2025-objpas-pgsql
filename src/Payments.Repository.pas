unit Payments.Repository;

{$mode ObjFPC}{$H+}

interface

uses
  Classes,
  SysUtils,
  fpjson,
  jsonparser,
  DateUtils,
  PQConnection,
  SQLDB,
  Payments.Data,
  Payments.Utils;

type
  TPaymentRepository = class
  private
    FConnection: TPQConnection;
    FTransaction: TSQLTransaction;
    FQuery: TSQLQuery;
    FSavePaymentCommand: String;
  public
    constructor Create;
    destructor Destroy; override;
    procedure PrepareSavePayment(APayment: TPayment; ARequestedAt: TDateTime; AIsDefault: Boolean);
    procedure ExecuteSavePayment;
    procedure DeletePayments;
    function GetSummary(AStartDate, AEndDate: TDateTime): string;
  end;

implementation

constructor TPaymentRepository.Create;
begin
  inherited Create;

  FConnection := TPQConnection.Create(nil);
  {$ifopt D+}
  FConnection.DatabaseName := 'payments_db';
  FConnection.HostName := 'localhost';
  FConnection.UserName := 'postgres';
  FConnection.Password := 'postgres';
  {$else}
  FConnection.DatabaseName := 'payments_db';
  FConnection.HostName := 'db';
  FConnection.UserName := 'postgres';
  FConnection.Password := 'postgres';
  {$endif}

  FTransaction := TSQLTransaction.Create(nil);

  //FConnection.Transaction := FTransaction;
  FTransaction.DataBase := FConnection;

  FQuery := TSQLQuery.Create(nil);
  FQuery.DataBase := FConnection;
  FQuery.Transaction := FTransaction;

  FConnection.Open;

  FSavePaymentCommand := '';
end;

destructor TPaymentRepository.Destroy;
begin
  FQuery.Free;
  FTransaction.Free;
  FConnection.Free;
  inherited Destroy;
end;

procedure TPaymentRepository.PrepareSavePayment(APayment: TPayment; ARequestedAt: TDateTime; AIsDefault: Boolean);
begin
  FSavePaymentCommand := Format(
    'INSERT INTO payments ' +
    '  (correlation_id, amount, processed_at, default_processor) ' +
    'VALUES ' +
    '  (''%s'', %.2f, ''%s'', %s) ',
    [APayment.CorrelationId, APayment.Amount, DateTimeToISO8601(ARequestedAt), BoolToStr(AIsDefault, 'true', 'false')]
  );
end;

procedure TPaymentRepository.ExecuteSavePayment;
begin
  try
    FTransaction.StartTransaction;
    FConnection.ExecuteDirect(FSavePaymentCommand, FTransaction);
    FTransaction.Commit;
  except
    on E: Exception do
    begin
      FTransaction.Rollback;
      raise;
    end;
  end;
end;

procedure TPaymentRepository.DeletePayments;
begin
  try
    FTransaction.StartTransaction;
    FConnection.ExecuteDirect('DELETE FROM payments', FTransaction);
    FTransaction.Commit;
  except
    on E: Exception do
    begin
      FTransaction.Rollback;
      raise;
    end;
  end;
end;

function TPaymentRepository.GetSummary(AStartDate, AEndDate: TDateTime): string;
var
  DefaultCount, FallbackCount: Integer;
  DefaultAmount, FallbackAmount: Currency;
begin
  DefaultCount := 0;
  FallbackCount := 0;
  DefaultAmount := 0.0;
  FallbackAmount := 0.0;
  try
    FTransaction.StartTransaction;
    FQuery.SQL.Text :=
      'SELECT default_processor, COUNT(*) as total_requests, COALESCE(SUM(amount), 0) as total_amount ' +
      'FROM payments ' +
      'WHERE processed_at >= :start_date AND processed_at <= :end_date ' +
      'group by default_processor';
    FQuery.ParamByName('start_date').AsDateTime := AStartDate;
    FQuery.ParamByName('end_date').AsDateTime := AEndDate;
    FQuery.Open;
    while not FQuery.EOF do
    begin
      if  FQuery.FieldByName('default_processor').AsBoolean then
      begin
        DefaultCount := FQuery.FieldByName('total_requests').AsInteger;
        DefaultAmount := FQuery.FieldByName('total_amount').AsCurrency;
      end
      else
      begin
        FallbackCount := FQuery.FieldByName('total_requests').AsInteger;
        FallbackAmount := FQuery.FieldByName('total_amount').AsCurrency;
      end;
      FQuery.Next;
    end;
    FQuery.Close;
    FTransaction.Commit;
  except
    on E: Exception do
    begin
      FTransaction.Rollback;
      raise;
    end;
  end;
  Result := Format(
    '{"default":{"totalRequests":%d,"totalAmount":%.2f},"fallback":{"totalRequests":%d,"totalAmount":%.2f}}',
    [DefaultCount, DefaultAmount, FallbackCount, FallbackAmount]
  );
end;

end.
