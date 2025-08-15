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
    FBaseUrl: String;
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

  if AIsDefault then
  begin
    FIsDefault := True;
    FMaxTries := 3;
    {$ifopt D+}
    FBaseUrl := 'http://localhost:8001';
    {$else}
    FBaseUrl := 'http://payment-processor-default:8080';
    {$endif}
  end
  else
  begin
    FIsDefault := False;
    FMaxTries := 1;
    {$ifopt D+}
    FBaseUrl := 'http://localhost:8002';
    {$else}
    FBaseUrl := 'http://payment-processor-fallback:8080';
    {$endif}
  end;
end;

destructor TPaymentWorkerThread.Destroy;
begin
  FRepository.Free;
  inherited Destroy;
end;

procedure TPaymentWorkerThread.Execute;
var
  PaymentPtr: PPayment;
  Client: TFPHTTPClient;
  Request: String;
  RequestedAt: TDateTime;
  Tries: Integer;
  Success: Boolean;
  Unavailable: Boolean;
begin
  Unavailable := False;
  Client := TFPHTTPClient.Create(nil);
  try
    Client.AddHeader('Content-Type', 'application/json');

    while not Terminated do
    begin
      PaymentPtr := FMyQueue.DequeueWithTimeout(1000);
      if PaymentPtr = nil then
      begin
        Continue;
      end;

      try
        RequestedAt := Now;

        Request := PaymentPtr^.ToJson(RequestedAt);

        Client.RequestBody := TRawByteStringStream.Create(Request);

        Success := False;
        Tries := 0;
        repeat
          Inc(Tries);

          if Unavailable then
            Sleep(500);

          FRepository.PrepareSavePayment(PaymentPtr^, RequestedAt, FIsDefault);

          Client.Post(FBaseUrl + '/payments');
          if (Client.ResponseStatusCode >= 200) and (Client.ResponseStatusCode <= 299) then
          begin
            try FRepository.ExecuteSavePayment; except end;
            Success := True;
            Unavailable := False;
            Break;
          end
          else
            Unavailable := True;
        until Tries >= FMaxTries;

        if Success then
          TPaymentQueue.FreeQueueData(PaymentPtr)
        else
          FGiveBackQueue.Enqueue(PaymentPtr);
      except
        FGiveBackQueue.Enqueue(PaymentPtr);
      end;
    end;
  finally
    Client.Free;
  end;
end;

end.

