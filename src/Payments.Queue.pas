unit Payments.Queue;

{$mode ObjFPC}{$H+}

interface

uses
  Classes,
  SysUtils,
  SyncObjs,
  fgl;

type
  TPaymentData = record
    Content: String;
  end;
  PPaymentData = ^TPaymentData;

  TDataList = specialize TFPGList<PPaymentData>;

  TPaymentQueue = class
  private
    FQueue: TDataList;
    FCriticalSection: TCriticalSection;
    FShutdown: Boolean;
    FWaitEvent: TEventObject;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Enqueue(const AContent: String);
    function Dequeue: PPaymentData;
    function DequeueWithTimeout(ATimeoutMs: Integer): PPaymentData;
    function IsEmpty: Boolean;
    function Count: Integer;
    procedure Shutdown;
    procedure Clear;
    class procedure FreeQueueData(AData: PPaymentData);
  end;

implementation

constructor TPaymentQueue.Create;
begin
  inherited Create;
  FQueue := TDataList.Create;
  FCriticalSection := TCriticalSection.Create;
  FWaitEvent := TEventObject.Create(nil, True, False, '');
  FShutdown := False;
end;

destructor TPaymentQueue.Destroy;
begin
  Shutdown;
  Clear;
  FreeAndNil(FQueue);
  FreeAndNil(FCriticalSection);
  FreeAndNil(FWaitEvent);
  inherited Destroy;
end;

procedure TPaymentQueue.Enqueue(const AContent: String);
var
  PaymentData: PPaymentData;
begin
  FCriticalSection.Acquire;
  try
    if FShutdown then
      Exit;

    New(PaymentData);
    PaymentData^.Content := AContent;

    FQueue.Add(PaymentData);
    FWaitEvent.SetEvent;
  finally
    FCriticalSection.Release;
  end;
end;

function TPaymentQueue.Dequeue: PPaymentData;
begin
  Result := nil;

  FCriticalSection.Acquire;
  try
    if FShutdown then
      Exit;

    if FQueue.Count > 0 then
    begin
      Result := FQueue[0];
      FQueue.Delete(0);

      if FQueue.Count = 0 then
        FWaitEvent.ResetEvent;
    end;
  finally
    FCriticalSection.Release;
  end;
end;

function TPaymentQueue.DequeueWithTimeout(ATimeoutMs: Integer): PPaymentData;
begin
  Result := nil;

  if FShutdown then
    Exit;

  Result := Dequeue;
  if Assigned(Result) then
    Exit;

  if FWaitEvent.WaitFor(ATimeoutMs) = wrSignaled then
  begin
    Result := Dequeue;
  end;
end;

function TPaymentQueue.IsEmpty: Boolean;
begin
  FCriticalSection.Acquire;
  try
    Result := FQueue.Count = 0;
  finally
    FCriticalSection.Release;
  end;
end;

function TPaymentQueue.Count: Integer;
begin
  FCriticalSection.Acquire;
  try
    Result := FQueue.Count;
  finally
    FCriticalSection.Release;
  end;
end;

procedure TPaymentQueue.Shutdown;
begin
  FCriticalSection.Acquire;
  try
    FShutdown := True;
    FWaitEvent.SetEvent;
  finally
    FCriticalSection.Release;
  end;
end;

procedure TPaymentQueue.Clear;
var
 I: Integer;
begin
  FCriticalSection.Acquire;
  try
    for I := 0 to FQueue.Count - 1 do
      Dispose(FQueue[I]);
    FQueue.Clear;
    FWaitEvent.ResetEvent;
  finally
    FCriticalSection.Release;
  end;
end;

class procedure TPaymentQueue.FreeQueueData(AData: PPaymentData);
begin
  if Assigned(AData) then
    Dispose(AData);
end;

end.
