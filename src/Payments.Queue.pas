unit Payments.Queue;

{$mode ObjFPC}{$H+}

interface

uses
  Classes,
  SysUtils,
  SyncObjs,
  fgl,
  Payments.Data;

type
  PPayment = ^TPayment;

  TDataList = specialize TFPGList<PPayment>;

  TPaymentQueue = class
  private
    FQueue: TDataList;
    FCriticalSection: TCriticalSection;
    FShutdown: Boolean;
    FWaitEvent: TEventObject;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Enqueue(APaymentPtr: PPayment);
    function Dequeue: PPayment;
    function DequeueWithTimeout(ATimeoutMs: Integer): PPayment;
    function IsEmpty: Boolean;
    function Count: Integer;
    procedure Shutdown;
    procedure Clear;
    class procedure FreeQueueData(APaymentPtr: PPayment);
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

procedure TPaymentQueue.Enqueue(APaymentPtr: PPayment);
begin
  FCriticalSection.Acquire;
  try
    if FShutdown then
      Exit;

    FQueue.Add(APaymentPtr);
    FWaitEvent.SetEvent;
  finally
    FCriticalSection.Release;
  end;
end;

function TPaymentQueue.Dequeue: PPayment;
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

function TPaymentQueue.DequeueWithTimeout(ATimeoutMs: Integer): PPayment;
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

class procedure TPaymentQueue.FreeQueueData(APaymentPtr: PPayment);
begin
  if Assigned(APaymentPtr) then
    Dispose(APaymentPtr);
end;

end.
