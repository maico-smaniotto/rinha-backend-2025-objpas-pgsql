unit Payments.Service;

{$mode ObjFPC}{$H+}

interface

uses
  Classes,
  SysUtils,
  Payments.Queue,
  Payments.Worker,
  Payments.Repository,
  Payments.Data;

type
  TPaymentService = class
  private
    FDefaultQueue: TPaymentQueue;
    FDefaultWorker: TPaymentWorkerThread;
    FFallbackQueue: TPaymentQueue;
    FFallbackWorker: TPaymentWorkerThread;
  public
    constructor Create; reintroduce;
    destructor Destroy; reintroduce; override;
    procedure EnqueuePayment(AContent: String);
    procedure EnqueuePaymentAsync(AContent: String);
    procedure DeletePayments;
    function GetSummary(AQuery: String): String;
  end;

  TProcWithParam = procedure(AContent: String) of object;
  TAsyncProc = class(TThread)
  private
    FProc: TProcWithParam;
    FParam: String;
  protected
    procedure Execute; override;
  public
    constructor Create(AProc: TProcWithParam; const AParam: String);
  end;

implementation

uses
  DateUtils;

function ExtractDateTimeParam(const S, Param: string; out Value: TDateTime): Boolean;
var
  StartPos, EndPos: Integer;
  DateStr: string;
begin
  Result := False;
  Value := 0;
  StartPos := Pos(Param + '=', S);
  if StartPos > 0 then
  begin
    StartPos := StartPos + Length(Param) + 1;
    EndPos := Pos('&', Copy(S, StartPos, MaxInt));
    if EndPos > 0 then
      DateStr := Copy(S, StartPos, EndPos - 1)
    else
      DateStr := Copy(S, StartPos, MaxInt);

    if DateStr <> '' then
    begin
      Value := ISO8601ToDate(DateStr);
      Result := True;
    end;
  end;
end;

{ TPaymentService }

procedure TPaymentService.EnqueuePaymentAsync(AContent: String);
begin
  TAsyncProc.Create(@EnqueuePayment, AContent);
end;

procedure TPaymentService.DeletePayments;
var
  Repository: TPaymentRepository;
begin
  Repository := TPaymentRepository.Create;
  try
    Repository.DeletePayments;
  finally
    Repository.Free;
  end;
end;

function TPaymentService.GetSummary(AQuery: String): String;
var
  StartDateTime,
  EndDateTime: TDateTime;
  Repository: TPaymentRepository;
begin
  ExtractDateTimeParam(AQuery, 'from', StartDateTime);
  ExtractDateTimeParam(AQuery, 'to', EndDateTime);

  Repository := TPaymentRepository.Create;
  try
    Result := Repository.GetSummary(StartDateTime, EndDateTime);
  finally
    Repository.Free;
  end;
end;

procedure TPaymentService.EnqueuePayment(AContent: String);
var
  PaymentPtr: PPayment;
  FQueue: TPaymentQueue;
begin
  FQueue := FDefaultQueue;

  if FQueue.Count > 1000 then
  begin
    FQueue := FFallbackQueue;

    if FQueue.Count > 200 then
      Exit;
  end;

  New(PaymentPtr);
  PaymentPtr^ := TPayment.FromJson(AContent);
  FQueue.Enqueue(PaymentPtr);
end;

constructor TPaymentService.Create;
begin
  inherited Create;

  FDefaultQueue := TPaymentQueue.Create;
  FFallbackQueue := TPaymentQueue.Create;

  FDefaultWorker := TPaymentWorkerThread.Create(FDefaultQueue, FFallbackQueue, True);
  FFallbackWorker := TPaymentWorkerThread.Create(FFallbackQueue, FDefaultQueue, False);

  FDefaultWorker.Start;
  FFallbackWorker.Start;
end;

destructor TPaymentService.Destroy;
begin
  FDefaultWorker.Terminate;
  FDefaultWorker.WaitFor;
  FDefaultWorker.Free;

  FFallbackWorker.Terminate;
  FFallbackWorker.WaitFor;
  FFallbackWorker.Free;

  FDefaultQueue.Free;
  FFallbackQueue.Free;

  inherited Destroy;
end;

{ TAsyncPaymentThread }

procedure TAsyncProc.Execute;
begin
  FProc(FParam);
end;

constructor TAsyncProc.Create(AProc: TProcWithParam; const AParam: String);
begin
  inherited Create(False);
  FreeOnTerminate := True;
  FProc := AProc;
  FParam := AParam;
end;

end.

