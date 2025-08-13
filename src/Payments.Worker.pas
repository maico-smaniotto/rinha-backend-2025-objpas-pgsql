unit Payments.Worker;

{$mode ObjFPC}{$H+}

interface

uses
  Classes,
  SysUtils,
  fphttpclient,
  Payments.Queue,
  Payments.Repository;

type
  TPaymentWorkerThread = class(TThread)
  private
    FMyQueue: TPaymentQueue;
    FGiveBackQueue: TPaymentQueue;
    FRepository: TPaymentRepository;
    FIsDefault: Boolean;
    FUrl: String;
    FMaxTries: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(AMyQueue: TPaymentQueue; AGiveBackQueue: TPaymentQueue; AIsDefault: Boolean); reintroduce;
    destructor Destroy; reintroduce; override;
  end;

implementation

uses
  Payments.Data;

constructor TPaymentWorkerThread.Create(AMyQueue: TPaymentQueue; AGiveBackQueue: TPaymentQueue; AIsDefault: Boolean);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FMyQueue := AMyQueue;
  FGiveBackQueue := AGiveBackQueue;

  FRepository := TPaymentRepository.Create;

  {$ifopt D+}
  if AIsDefault then
  begin
    FIsDefault := True;
    FUrl := 'http://localhost:8001';
    FMaxTries := 50;
  end
  else
  begin
    FIsDefault := False;
    FUrl := 'http://localhost:8002';
    FMaxTries := 1;
  end;
  {$else}
  if AIsDefault then
  begin
    FIsDefault := True;
    FUrl := 'http://payment-processor-default:8080';
    FMaxTries := 50;
  end
  else
  begin
    FIsDefault := False;
    FUrl := 'http://payment-processor-fallback:8080';
    FMaxTries := 1;
  end;
  {$endif}
end;

destructor TPaymentWorkerThread.Destroy;
begin
  FRepository.Free;
  inherited Destroy;
end;

procedure TPaymentWorkerThread.Execute;
var
  PaymentData: PPaymentData;
  Client: TFPHTTPClient;
  Request: String;
  Payment: TPayment;
  RequestedAt: TDateTime;
  Tries: Integer;
  Success: Boolean;
begin
  while not Terminated do
  begin
    PaymentData := FMyQueue.DequeueWithTimeout(1000);
    if PaymentData = nil then
    begin
      Sleep(100);
      Continue;
    end;

    Payment := TPayment.FromJson(PaymentData^.Content);

    Client := TFPHTTPClient.Create(nil);
    try
      try
        RequestedAt := Now;

        Request := PaymentData^.Content;
        Request := Trim(Request);
        Request := Copy(Request, 1, Length(Request) -1) + ',"requestedAt":"' + FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss".000Z"', RequestedAt) + '"}';

        Client.AddHeader('Content-Type', 'application/json');
        //Client.RequestBody := TRawByteStringStream.Create(Request);
        Client.RequestBody := TStringStream.Create(Request);

        Success := False;
        Tries := 0;
        repeat
          Client.Post(FUrl + '/payments');
          Inc(Tries);

          if Client.ResponseStatusCode = 200 then
          begin
            FRepository.SavePayment(Payment, RequestedAt, FIsDefault);
            Success := True;
            Break;
          end;
        until Tries = FMaxTries;

        if not Success then
          FGiveBackQueue.Enqueue(PaymentData^.Content);
      except
        FGiveBackQueue.Enqueue(PaymentData^.Content);
      end;
    finally
      Client.Free;
      TPaymentQueue.FreeQueueData(PaymentData);
    end;
  end;
end;

end.

