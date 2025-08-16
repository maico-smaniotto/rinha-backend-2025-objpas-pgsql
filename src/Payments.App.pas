unit Payments.App;

{$mode ObjFPC}{$H+}

interface

uses
  Classes,
  SysUtils,
  fpHTTP,
  HTTPDefs,
  HTTPRoute,
  custhttpapp,
  Payments.Service;

type
  TPaymentsApp = class(TCustomHTTPApplication)
  private
    FPaymentsService: TPaymentService;
    procedure InitializeRoutes;
    procedure GetSummary(ARequest: TRequest; AResponse: TResponse);
    procedure PostPayment(ARequest: TRequest; AResponse: TResponse);
    procedure PostPurge(ARequest: TRequest; AResponse: TResponse);
  protected
    procedure DoRun; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

{ TPaymentsApp }

procedure TPaymentsApp.InitializeRoutes;
begin
  HTTPRouter.RegisterRoute('/payments', rmPost, @PostPayment);
  HTTPRouter.RegisterRoute('/payments-summary', rmGet, @GetSummary);
  HTTPRouter.RegisterRoute('/purge-payments', rmPost, @PostPurge);
end;

procedure TPaymentsApp.GetSummary(ARequest: TRequest; AResponse: TResponse);
begin
  AResponse.Content := FPaymentsService.GetSummary(ARequest.QueryString);
  AResponse.Code := 200;
end;

procedure TPaymentsApp.PostPayment(ARequest: TRequest; AResponse: TResponse);
begin
  //FPaymentsService.EnqueuePaymentAsync(ARequest.Content);
  FPaymentsService.EnqueuePayment(ARequest.Content);
  AResponse.Code := 202;
end;

procedure TPaymentsApp.PostPurge(ARequest: TRequest; AResponse: TResponse);
begin
  FPaymentsService.DeletePayments;
  AResponse.Code := 200;
end;

procedure TPaymentsApp.DoRun;
begin
  {$ifopt D+}
  HostName := 'localhost';
  Port := 8099;
  {$else}
  HostName := '0.0.0.0';
  Port := 9999;
  {$endif}

  Threaded := True;

  inherited DoRun;
end;

constructor TPaymentsApp.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FPaymentsService := TPaymentService.Create;
  InitializeRoutes;
end;

destructor TPaymentsApp.Destroy;
begin
  FPaymentsService.Free;

  inherited Destroy;
end;

end.

