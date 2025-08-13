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
  Payments.Data;

type
  TPaymentRepository = class
  private
    FConnection: TPQConnection;
    FTransaction: TSQLTransaction;
    FQuery: TSQLQuery;
  public
    constructor Create;
    destructor Destroy; override;

    procedure SavePayment(APayment: TPayment; ARequestedAt: TDateTime; AIsDefault: Boolean);
    function GetSummary(AStartDate, AEndDate: TDateTime): string;
  end;

implementation

constructor TPaymentRepository.Create;
begin
  inherited Create;

  FConnection := TPQConnection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);
  FQuery := TSQLQuery.Create(nil);

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

  FConnection.Transaction := FTransaction;
  FTransaction.DataBase := FConnection;

  FQuery.DataBase := FConnection;
  FQuery.Transaction := FTransaction;
end;

destructor TPaymentRepository.Destroy;
begin
  FQuery.Free;
  FTransaction.Free;
  FConnection.Free;
  inherited Destroy;
end;

procedure TPaymentRepository.SavePayment(APayment: TPayment; ARequestedAt: TDateTime; AIsDefault: Boolean);
begin
  try
    if not FConnection.Connected then
      FConnection.Open;

    FTransaction.StartTransaction;

    FQuery.SQL.Text :=
      'INSERT INTO payments ' +
      '  (correlation_id, amount, processed_at, default_processor) ' +
      'VALUES ' +
      '  (:correlation_id, :amount, :processed_at, :default_processor) ';
    FQuery.ParamByName('correlation_id').AsString := APayment.CorrelationId;
    FQuery.ParamByName('amount').AsCurrency := APayment.Amount;
    FQuery.ParamByName('processed_at').AsDateTime := ARequestedAt;
    FQuery.ParamByName('default_processor').AsBoolean := AIsDefault;

    FQuery.ExecSQL;
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
    if not FConnection.Connected then
      FConnection.Open;

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
