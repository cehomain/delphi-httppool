{

http://code.google.com/p/delphi-httppool/
HTTPPool - Multithreaded HTTP request management library written with
	OmniThreadLib and Synapse HTTPSend components.
  JSON support using SuperObject.
  
Author: WILLIAM YZ YANG
Email: flyingdragontooth at gmail.com
Date: 2011.06.02

[History]
2012.4.3
--------

* Added IHTTPJob, IHTTPPool, allow more flexible architecture
* Added BeforeRequest callback, called before each request gets processed,
    allowed job owner to decide whether to cancel or push job to the end of queue
*


2011.06.02
----------
* Does http requests asynchronously
* Handles all completed requests in your main thread (or which ever)
* supports common usage through: ContentAsString, ContentAsJSON and ContentAsImage
* Counters on queued, completed requests.
* Allows http request to be queued with custom tag object

[Todo]
* Support requests per second limit
* Support concurrent requests limit per domain
* Support cookie storage
* Support auto cache

[References]

  OmniThreadLib Homepage:  http://code.google.com/p/omnithreadlibrary/
  Synapse Homepage: http://synapse.ararat.cz/doku.php/start
  SuperObject: http://www.progdigy.com/?page_id=6

}
unit httppool;

interface

uses Classes, SysUtils, OtlComm, OtlTask, OtlTaskControl, OtlEventMonitor,
  HTTPSend, Contnrs, Graphics, ThreadObjectList, SuperObject, ActiveX, httppoolInterfaces
  ;

type

  THTTPJob = class;
  THTTPJobEvent = procedure(ASender: TObject; AJob: THTTPJob) of object;
  THTTPJobRequestEvent = procedure(ASender: TObject; AJob: THTTPJob) of object;
  THTTPJobBeforeRequestEvent = procedure(ASender: TObject; AJob: THTTPJob; var AAction: Integer) of object;

  THTTPJob = class(TInterfacedObject, IHTTPJob)
  private
    FHeaders: TStringList;
    FMethod: String;
    FCookies: TStringList;
    FURL: String;
    FOnError: THTTPJobRequestEvent;
    FOnSuccess: THTTPJobRequestEvent;
    FOnBeforeRequest: THTTPJobBeforeRequestEvent;
    FData: TStream;
    FContentType: String;
    FTagObject: TObject;
    FTag: Integer;
    FResultCode: Integer;
    FCallback: IHTTPJobCallback;

    procedure SetCookies(const Value: TStringList);
    procedure SetHeaders(const Value: TStringList);
    procedure SetOnBeforeRequest(const Value: THTTPJobBeforeRequestEvent);
    procedure SetOnError(const Value: THTTPJobRequestEvent);
    procedure SetOnSuccess(const Value: THTTPJobRequestEvent);

    procedure SetTagObject(const Value: TObject);
    function GetCookies: TStringList;
    function GetHeaders: TStringList;
    function GetTagObject: TObject;

  protected
    procedure DoSuccess(ASender: TObject); virtual;
    procedure DoError(ASender: TObject); virtual;
//    procedure DoBeforeRequest(ASender: TObject); virtual;


  public
    constructor Create(AURL: String;
      const AMethod: String = 'GET';
      const AHeaders: TStringList = nil;
      const ACookies: TStringList = nil);

    destructor Destroy; override;

    {$IFDEF HTTPPOOL_IMAGESUPPORT}
    function ContentAsImage: TGraphic;
    {$ENDIF}

    procedure BeforeRequest(var AAction: Integer);
    function ContentAsString: String; safecall;
    function ContentAsJSON: ISuperObject; safecall;
    function ContentAsStream: IStream; safecall;

    procedure SetMethod(const Value: String); safecall;
    procedure SetURL(const Value: String); safecall;
    procedure SetData(const Value: TStream);
    procedure SetContentType(const Value: String); safecall;
    function getDataLength: Cardinal; safecall;
    function getDataPtr: Pointer; safecall;
    procedure SetTag(const Value: Integer);  safecall;
    function GetURL: String; safecall;
    procedure SetResultCode(const Value: Integer); safecall;
    function GetContentType: String; safecall;
    function GetData: TStream;
    function GetMethod: String;  safecall;
    function GetResultCode: Integer;  safecall;
    function GetTag: Integer;  safecall;

    procedure SetCallback(const Value: IHTTPJobCallback);  safecall;
    procedure SetCookieText(const Value: String);  safecall;
    procedure SetHeaderText(const Value: String);  safecall;
    function GetCallback: IHTTPJobCallback; safecall;
    function GetCookieText: String; safecall;
    function GetHeaderText: String; safecall;


    property URL: String read GetURL write SetURL;
    property Method: String read GetMethod write SetMethod;
    property ResultCode: Integer read GetResultCode write SetResultCode;

    property Headers: TStringList read GetHeaders write SetHeaders;
    property Cookies: TStringList read GetCookies write SetCookies;

    property HeaderText: String read GetHeaderText write SetHeaderText;
    property CookieText: String read GetCookieText write SetCookieText;
    property Callback: IHTTPJobCallback read GetCallback write SetCallback;

    property OnSuccess: THTTPJobRequestEvent read FOnSuccess write SetOnSuccess;
    property OnError: THTTPJobRequestEvent read FOnError write SetOnError;
    property OnBeforeRequest: THTTPJobBeforeRequestEvent read FOnBeforeRequest write SetOnBeforeRequest;
    property Data: TStream read GetData write SetData;
    property DataPtr: Pointer read getDataPtr;
    property DataLength: Cardinal read getDataLength;
    property ContentType: String read GetContentType write SetContentType;
    property TagObject: TObject read GetTagObject write SetTagObject;
    property Tag: Integer read GetTag write SetTag;
  end;

  THTTPJobQueue = class(TObjectQueue)
  public
    function Push(AObject: THTTPJob): THTTPJob;
    function Pop: THTTPJob;
    function Peek: THTTPJob;
  end;


  THTTPWorker = class(TOmniWorker)
  private
    FHTTPSend: THTTPSend;
    FActiveJob: THTTPJob;
    FName: String;
    procedure SetActiveJob(const Value: THTTPJob);
    procedure SetName(const Value: String);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Work(const ATask: IOmniTask);
    property HTTPSend: THTTPSend read FHTTPSend;
    property ActiveJob: THTTPJob read FActiveJob write SetActiveJob;
    property Name: String read FName write SetName;
  end;

  THTTPWorkerCount = 1..MAX_HTTPWORKERS;

  THTTPWorkPool = class(TInterfacedObject, IHTTPWorkPool)
  private
    fJobList: TThreadObjectList;
    fQueue: THTTPJobQueue;
    FWorkerCount: THTTPWorkerCount;
    fHTTPWorkMon: TOmniEventMonitor;
    FSelfTask: IOmniTaskControl;
    FOnSuccess: THTTPJobRequestEvent;
    FOnBeforeRequest: THTTPJobRequestEvent;
    FOnError: THTTPJobRequestEvent;
    FRequestsPerSecond: Cardinal;
  	fCompletedRequests: Integer;
    procedure SetWorkerCount(const Value: THTTPWorkerCount);
    procedure DoWorkTaskMessage(const task: IOmniTaskControl; const msg: TOmniMessage);
    procedure SetOnBeforeRequest(const Value: THTTPJobRequestEvent);
    procedure SetOnError(const Value: THTTPJobRequestEvent);
    procedure SetOnSuccess(const Value: THTTPJobRequestEvent);
    procedure SetRequestsPerSecond(const Value: Cardinal);

    procedure RemoveJob(AJob: THTTPJob);
    procedure PushJob(AJob: THTTPJob);
    
  protected
//    procedure DoBeforeRequest(AJob: THTTPJob); virtual;
    procedure DoSuccess(AJob: THTTPJob); virtual;
    procedure DoError(AJob: THTTPJob); virtual;
    function getCompletedRequests: Cardinal; virtual;
    function getQueuedRequests: Cardinal; virtual;



  public
    constructor Create;
    destructor Destroy; override;

    function Job(AURL: String;
      const AMethod: String = 'GET';
      const AParam: String = '';
      const AHeaders: TStringList = nil;
      const ACookies: TStringList = nil): THTTPJob;

    function JobTagged(AURL: String;
      const AMethod: String = 'GET';
      const AParam: String = '';
      const ATagObject: TObject = nil;
      const ATag: Integer = 0;
      const AHeaders: TStringList = nil;
      const ACookies: TStringList = nil): THTTPJob;



    function HTTPWorkPool_Job(AURL: String;
      const AMethod: String = 'GET';
      const AParam: String = '';
      const ACallback: IHTTPJobCallback = nil;
      const AHeaders: String = '';
      const ACookies: String = ''): IHTTPJob; safecall;

    function HTTPWorkPool_JobTagged(AURL: String;
      const AMethod: String = 'GET';
      const AParam: String = '';
      const ACallback: IHTTPJobCallback = nil;
      const ATag: Integer = 0;
      const AHeaders: String = '';
      const ACookies: String = ''): IHTTPJob; safecall;

    function IHTTPWorkPool.Job = HTTPWorkPool_Job;
    function IHTTPWorkPool.JobTagged = HTTPWorkPool_JobTagged;

    function Get(AURL: String;
      const AParam: String = '';
      const ACallback: IHTTPJobCallback = nil;
      const AHeaders: String = '';
      const ACookies: String = ''): IHTTPJob; safecall;

    function Post(AURL: String;
      const AParam: String = '';
      const ACallback: IHTTPJobCallback = nil;
      const AHeaders: String = '';
      const ACookies: String = ''): IHTTPJob; safecall;

    function Head(AURL: String;
      const AParam: String = '';
      const ACallback: IHTTPJobCallback = nil;
      const AHeaders: String = '';
      const ACookies: String = ''): IHTTPJob; safecall;

    procedure Pooling(const ATask: IOmniTask);
    property WorkerCount: THTTPWorkerCount read FWorkerCount write SetWorkerCount;

    property OnSuccess: THTTPJobRequestEvent read FOnSuccess write SetOnSuccess;
    property OnError: THTTPJobRequestEvent read FOnError write SetOnError;
//    property OnBeforeRequest: THTTPJobRequestEvent read FOnBeforeRequest write SetOnBeforeRequest;

    property RequestsPerSecond: Cardinal read FRequestsPerSecond write SetRequestsPerSecond;
    property CompletedRequests: Cardinal read getCompletedRequests;
    property QueuedRequests: Cardinal read getQueuedRequests;

  end;




implementation

uses Windows, HTTPUtil
{$IFDEF USE_CODESITE}
,CodeSiteLogging
{$ENDIF}
{$IFDEF HTTPPOOL_IMAGESUPPORT}
, GifImg, PngImage, Jpeg
{$ENDIF}
;
{ THTTPWorker }

constructor THTTPWorker.Create;
begin
  inherited Create;
  fHTTPSend := THTTPSend.Create;
  fActiveJob := nil;
end;

destructor THTTPWorker.Destroy;
begin
  fHTTPSend.Free;
end;

procedure THTTPWorker.SetActiveJob(const Value: THTTPJob);
begin
  FActiveJob := Value;
end;

procedure THTTPWorker.SetName(const Value: String);
begin
  FName := Value;
end;

procedure THTTPWorker.Work(const ATask: IOmniTask);

  procedure ProcessJob(AJob: THTTPJob);
  begin

  	{$IFDEF USE_CODESITE}
    CodeSite.Send(FName + ': Start to download ' + AJob.URL);
    {$ENDIF}

      FHTTPSend.Clear;
      //ATask.Comm.Send(HTTPWORKER_JOB_BEFOREQUEST, [Self, FHTTPSend]);
      FHTTPSend.Headers.Assign(AJob.Headers);
      FHTTPSend.Cookies.Assign(AJob.Cookies);
      if FHTTPSend.HTTPMethod(AJob.Method, AJob.URL) then
      begin

        {$IFDEF USE_CODESITE}
        CodeSite.Send(FName + ': Download Success ' + AJob.URL);
        {$ENDIF}
    
        AJob.ContentType := ExtractHeader(FHTTPSend.Headers, 'Content-Type');

        AJob.Data.CopyFrom(FHTTPSend.Document, FHTTPSend.Document.Size);
        AJob.Headers.Assign(FHTTPSend.Headers);
        AJob.Cookies.Assign(FHTTPSend.Cookies);
        AJob.ResultCode := FHTTPSend.ResultCode;

        {$IFDEF USE_CODESITE}
        CodeSite.Send(FName + ': Content-Type= ' + AJob.ContentType );
        CodeSite.Send(FName + ': Content-Length= ' + IntToStr(FHTTPSend.Document.Size));
        CodeSite.Send(FName + ': Content', Utf8Decode(AJob.ContentAsString));
        {$ENDIF}


        ATask.Comm.Send(HTTPWORKER_JOB_SUCCESS, AJob)
      end
      else
        ATask.Comm.Send(HTTPWORKER_JOB_ERROR, AJob);


    //ATask.Comm.Send(HTTPWORKER_JOB_AFTERQUEST, [Self, FHTTPSend]);
  end;

var
  msg: TOmniMessage;
begin
//	ActiveJob := nil;
  while not ATask.Terminated do
  begin
    if ATask.Comm.ReceiveWait(msg, 100) then
    begin
      if msg.MsgID = HTTPWORKER_JOB then
      begin
        try
          ProcessJob(ActiveJob);
        finally
          ActiveJob := nil;
        end;
      end;
    end;
    Sleep(100);
  end;
end;

{ THTTPJob }
{$IFDEF HTTPPOOL_IMAGESUPPORT}
function THTTPJob.ContentAsImage: TGraphic;
var
	fname: String;
begin
	Result := nil;
  if ContentType = 'image/gif' then
  	Result := TGifImage.Create
  else if ContentType = 'image/jpeg' then
  	Result := TJpegImage.Create
  else if ContentType = 'image/png' then
  	Result := TPngObject.Create;

  if Result <> nil then
	begin
    TMemoryStream(Data).SaveToFile('tmp');
    Data.Seek(0, 0);
  	Result.LoadFromStream(Data);
  end;
end;
{$ENDIF}

procedure THTTPJob.BeforeRequest(var AAction: Integer);
begin
  if Assigned(FOnBeforeRequest) then
    FOnBeforeRequest(Self, Self, AAction);

  if Assigned(FCallback) then
    FCallback.OnBeforeRequest(Self, AAction);
end;

function THTTPJob.ContentAsJSON: ISuperObject;
begin
  Result := SO(UTF8Decode(ContentAsString));
end;

function THTTPJob.ContentAsStream: IStream;
begin
  Result := TStreamAdapter.Create(fData);
end;

function THTTPJob.ContentAsString: String;
begin
	with TStringStream.Create('') do
  begin
  	try
    	Data.Seek(0, 0);
		  CopyFrom(Data, Data.Size);
      Result := DataString;
    finally
	    Free;
    end;
  end;
end;

constructor THTTPJob.Create(AURL: String; const AMethod: String; const AHeaders,
  ACookies: TStringList);
begin
  inherited Create;
  fURL := AURL;
  fMethod := AMethod;
  
  FHeaders := TStringList.Create;
  if AHeaders <> nil then
	  FHeaders.Assign(AHeaders);

  FCookies := TStringList.Create;
  if ACookies <> nil then
	  FCookies.Assign(ACookies);

  FData := TMemoryStream.Create;
end;

destructor THTTPJob.Destroy;
begin
	FData.Free;
  FHeaders.Free;
  FCookies.Free;
  inherited;
end;

//procedure THTTPJob.DoBeforeRequest(ASender: TObject);
//var
//  Cancel: Boolean;
//begin
//  if Assigned(FOnBeforeRequest) then
//    FOnBeforeRequest(ASender, Self);
//
//end;

procedure THTTPJob.DoError(ASender: TObject);
begin
  if Assigned(FOnError) then
    FOnError(ASender, Self);

  if Assigned(FCallback) then
    fCallback.OnError(Self);
end;

procedure THTTPJob.DoSuccess(ASender: TObject);
begin
  if Assigned(FOnSuccess) then
    FOnSuccess(ASender, Self);

  if Assigned(FCallback) then
    fCallback.OnSuccess(Self);
end;

function THTTPJob.GetCallback: IHTTPJobCallback;
begin
  Result := fCallback;
end;

function THTTPJob.GetContentType: String;
begin
  Result := FContentType;
end;

function THTTPJob.GetCookies: TStringList;
begin
  Result := FCookies;
end;

function THTTPJob.GetCookieText: String;
begin
  Result := fCookies.Text;
end;

function THTTPJob.GetData: TStream;
begin
  Result := fData;
end;

function THTTPJob.getDataLength: Cardinal;
begin
	Result := fData.Size;
end;

function THTTPJob.getDataPtr: Pointer;
begin
  Result := TMemoryStream(fData).Memory;
end;

function THTTPJob.GetHeaders: TStringList;
begin
  Result := fHeaders;
end;

function THTTPJob.GetHeaderText: String;
begin
  Result := fHeaders.Text;
end;

function THTTPJob.GetMethod: String;
begin
  Result := FMethod;
end;

function THTTPJob.GetResultCode: Integer;
begin
  Result := FResultCode;
end;

function THTTPJob.GetTag: Integer;
begin
  Result := fTag;
end;

function THTTPJob.GetTagObject: TObject;
begin
  Result := fTagObject;
end;

function THTTPJob.GetURL: String;
begin
  Result := fURL;
end;

procedure THTTPJob.SetCallback(const Value: IHTTPJobCallback);
begin
  FCallback := Value;
end;

procedure THTTPJob.SetContentType(const Value: String);
begin
  FContentType := Value;
end;

procedure THTTPJob.SetCookies(const Value: TStringList);
begin
  FCookies.Assign(Value);
end;

procedure THTTPJob.SetCookieText(const Value: String);
begin
  fCookies.Text := Value;
end;

procedure THTTPJob.SetData(const Value: TStream);
begin
  FData := Value;
end;

procedure THTTPJob.SetHeaders(const Value: TStringList);
begin
  FHeaders.Assign( Value );
end;

procedure THTTPJob.SetHeaderText(const Value: String);
begin
  FHeaders.Text := Value;
end;

procedure THTTPJob.SetMethod(const Value: String);
begin
  FMethod := Value;
end;

procedure THTTPJob.SetOnBeforeRequest(const Value: THTTPJobBeforeRequestEvent);
begin
  FOnBeforeRequest := Value;
end;

procedure THTTPJob.SetOnError(const Value: THTTPJobRequestEvent);
begin
  FOnError := Value;
end;

procedure THTTPJob.SetOnSuccess(const Value: THTTPJobRequestEvent);
begin
  FOnSuccess := Value;
end;

procedure THTTPJob.SetResultCode(const Value: Integer);
begin
  FResultCode := Value;
end;

procedure THTTPJob.SetTag(const Value: Integer);
begin
  FTag := Value;
end;

procedure THTTPJob.SetTagObject(const Value: TObject);
begin
  FTagObject := Value;
end;

procedure THTTPJob.SetURL(const Value: String);
begin
  FURL := Value;
end;

{ THTTPJobQueue }

function THTTPJobQueue.Peek: THTTPJob;
begin
  Result := THTTPJob(inherited Peek);
end;

function THTTPJobQueue.Pop: THTTPJob;
begin
  Result := THTTPJob(inherited Pop);
end;

function THTTPJobQueue.Push(AObject: THTTPJob): THTTPJob;
begin
  Result := THTTPJob(inherited Push(AObject));
end;

{ THTTPWorkPool }

constructor THTTPWorkPool.Create;
begin
  inherited Create;
  fJobList := TThreadObjectList.Create;
  fQueue := THTTPJobQueue.Create;
  fJobList.OwnsObjects := True;
  fHTTPWorkMon := TOmniEventMonitor.Create(nil);
  fHTTPWorkMon.OnTaskMessage := DoWorkTaskMessage;
  FRequestsPerSecond := 0;
  FSelfTask := CreateTask(Self.Pooling).Run();
end;

destructor THTTPWorkPool.Destroy;
begin
  fHTTPWorkMon.Free;
  fJobList.Free;
  fQueue.Free;
  inherited;
end;

procedure THTTPWorkPool.DoError(AJob: THTTPJob);
begin
	AJOb.DoError(Self);
  if Assigned(FOnError) then FOnError(Self, AJob);  
end;

procedure THTTPWorkPool.DoSuccess(AJob: THTTPJob);
begin
	Inc(fCompletedRequests);
	AJOb.DoSuccess(Self);
  if Assigned(FOnSuccess) then FOnSuccess(Self, AJob);
end;

procedure THTTPWorkPool.DoWorkTaskMessage(const task: IOmniTaskControl; const msg: TOmniMessage);
var
//  msg: TOmniMessage;
  AJob: THTTPJob;
begin

    AJob := THTTPJob(Msg.MsgData.AsObject);

    case msg.MsgID of
//    HTTPWORKER_JOB_BEFOREREQUEST:
//      DoBeforeRequest(AJob);
//    HTTPWORKER_JOB_AFTERREQUEST:
//      AJob.DoAfterRequest(Self, AHTTPSend);
    HTTPWORKER_JOB_SUCCESS:
      DoSuccess(AJob);
    HTTPWORKER_JOB_ERROR:
      DoError(AJob);
    end;

end;

function THTTPWorkPool.Get(AURL: String; const AParam: String;
  const ACallback: IHTTPJobCallback; const AHeaders,
  ACookies: String): IHTTPJob;
var
  job: THTTPJob;
begin

  job := THTTPJob.Create(AURL, 'GET');
  job.HeaderText := AHeaders;
  job.CookieText := ACookies;
  job.Callback := ACallback;
  PushJob(job);
  Result := job;

end;


function THTTPWorkPool.getCompletedRequests: Cardinal;
begin
	Result := fCompletedRequests;
end;

function THTTPWorkPool.getQueuedRequests: Cardinal;
begin
  Result := fQueue.Count;
end;

function THTTPWorkPool.Head(AURL: String; const AParam: String;
  const ACallback: IHTTPJobCallback; const AHeaders,
  ACookies: String): IHTTPJob;
var
  job: THTTPJob;
begin

  job := THTTPJob.Create(AURL, 'HEAD');
  job.HeaderText := AHeaders;
  job.CookieText := ACookies;
  job.Callback := ACallback;
  PushJob(job);
  Result := job;

end;
function THTTPWorkPool.HTTPWorkPool_Job(AURL: String; const AMethod,
  AParam: String; const ACallback: IHTTPJobCallback; const AHeaders,
  ACookies: String): IHTTPJob;
var
  job: THTTPJob;
begin

  job := THTTPJob.Create(AURL, AMethod);
  job.Callback := ACallback;
  job.HeaderText := AHeaders;
  job.CookieText := ACookies;
  PushJob(job);
  Result := job;

end;

function THTTPWorkPool.HTTPWorkPool_JobTagged(AURL: String; const AMethod,
  AParam: String; const ACallback: IHTTPJobCallback; const ATag: Integer;
  const AHeaders, ACookies: String): IHTTPJob;
var
  job: THTTPJob;
begin

  job := THTTPJob.Create(AURL, AMethod);
  job.HeaderText := AHeaders;
  job.CookieText := ACookies;
  job.Tag := ATag;
  job.Callback := ACallback;
  PushJob(job);
  Result := job;

end;



procedure THTTPWorkPool.PushJob(AJob: THTTPJob);
begin
  {$IFDEF USE_CODESITE}CodeSite.EnterMethod( Self, 'PushJob' );{$ENDIF}
  fJobList.LockList;
  try
    if fJobList.IndexOf(AJob) < 0 then
    begin
      fJobList.Add(AJob);
      fQueue.Push(AJob);
    end;
  finally
    fJobList.UnlockList;
  end;
  {$IFDEF USE_CODESITE}CodeSite.ExitMethod( Self, 'PushJob' );{$ENDIF}
end;

procedure THTTPWorkPool.RemoveJob(AJob: THTTPJob);
begin
  fJobList.LockList;
  try
    fJobList.Remove(AJob);
    AJob.Free;
  finally
    fJobList.UnlockList;
  end;
end;

function THTTPWorkPool.Job(AURL: String;
      const AMethod: String = 'GET';
      const AParam: String = '';
      const AHeaders: TStringList = nil;
      const ACookies: TStringList = nil): THTTPJob;
begin
  {$IFDEF USE_CODESITE}CodeSite.EnterMethod( Self, 'Job' );{$ENDIF}
  Result := THTTPJob.Create(AURL, AMethod, AHeaders, ACookies);
  PushJob(Result);
  {$IFDEF USE_CODESITE}CodeSite.ExitMethod( Self, 'Job' );{$ENDIF}
end;

function THTTPWorkPool.JobTagged(AURL: String; const AMethod, AParam: String;
  const ATagObject: TObject; const ATag: Integer; const AHeaders,
  ACookies: TStringList): THTTPJob;
var
	URL: String;
begin
  {$IFDEF USE_CODESITE}CodeSite.EnterMethod( Self, 'JobTagged' );{$ENDIF}
	if Length(AParam) = 0 then URL := AURL else URL := AURL + '?' + AParam;
  Result := THTTPJob.Create(URL, AMethod, AHeaders, ACookies);
  Result.TagObject := ATagObject;
  Result.Tag := ATag;
  PushJob(Result);
  {$IFDEF USE_CODESITE}CodeSite.ExitMethod( Self, 'JobTagged' );{$ENDIF}
end;

procedure THTTPWorkPool.Pooling(const ATask: IOmniTask);

var
  fWorkers: array[1..MAX_HTTPWORKERS] of THTTPWorker;
  fTaskCtrls: array[1..MAX_HTTPWORKERS] of IOmniTaskControl;

  function GetWorkerTask(AIndex: THTTPWorkerCount): IOmniTaskControl;
  begin
    if not Assigned(fTaskCtrls[AIndex]) then
    begin

      fTaskCtrls[AIndex] := CreateTask(fWorkers[AIndex].Work);
      fTaskCtrls[AIndex].MonitorWith(fHTTPWorkMon);
//      fTaskCtrls[AIndex].OnMessage(DoWorkTaskMessage);
        fTaskCtrls[AIndex].Run;
    end;
    Result := fTaskCtrls[AIndex];
  end;

  function GiveJobToNextWorker(AJob: THTTPJob): Boolean;
  var
    i: Integer;
  begin
    Result := False;
    for I := 1 to MAX_HTTPWORKERS do
    begin
      if FWorkers[i].ActiveJob = nil then
      begin
      	FWorkers[i].ActiveJob := AJob;
        GetWorkerTask(i).Comm.Send(HTTPWORKER_JOB);
        Result := True;
        Break;
      end;
    end;
  end;


var
  fCurrMPS: Integer;
  fStart, fDelay: Int64;
  Job: THTTPJob;
  action, i: Integer;
begin

  for I := 1 to MAX_HTTPWORKERS do
  begin
    fWorkers[i] := THTTPWorker.Create;
    fWorkers[i].Name := 'Worker #' + IntToStr(i);
  end;

  try

    while not ATask.Terminated do
    begin

      fStart := GetTickCount;
      fCurrMPS := 0;

      // 队列中至少有一个 或
    	while fQueue.AtLeast(1)do
      begin

        // 需要检测 最大HTTP请求频率
        if (FRequestsPerSecond > 0) and
        	(GetTickCount-fStart < 1000) and
          (fCurrMPS < fRequestsPerSecond) then
        begin

          {$IFDEF USE_CODESITE}
          CodeSite.Send('Controlling RPS: Current RPS = %d, RequestsPerSecond = %d',
          	[fCurrMPS, fRequestsPerSecond]);
          {$ENDIF}
        	Break;

        end;

        Job := fQueue.Pop;
        action := BEFORE_REQUEST_ACTION_NONE;
        Job.BeforeRequest(action);
        if action = BEFORE_REQUEST_ACTION_CANCEL then
        begin
          // Remove Job
          RemoveJob(Job);
          Continue;
        end
        else if action = BEFORE_REQUEST_ACTION_WAIT then
        begin
          // PushJob to the end of queue
          PushJob(Job);
          Continue;
        end;

        while not GiveJobToNextWorker(Job) do
        begin
        	Sleep(0);
        	// Next
//          ControlRPS;
        end;
        Inc(fCurrMPS);
        Sleep(0);

      end;

      fDelay := (1000 - (GetTickCount-fStart));
      if (fDelay > 0) then
        Sleep(fDelay);

    end;
  finally

    for I := 1 to MAX_HTTPWORKERS do
    begin
      if fWorkers[i] <> nil then fWorkers[i].Free;
      
    end;
  end;
end;

function THTTPWorkPool.Post(AURL: String; const AParam: String;
  const ACallback: IHTTPJobCallback; const AHeaders,
  ACookies: String): IHTTPJob;
var
  job: THTTPJob;
begin

  job := THTTPJob.Create(AURL, 'POST');
  job.HeaderText := AHeaders;
  job.CookieText := ACookies;
  job.Callback := ACallback;
  PushJob(job);
  Result := job;

end;

procedure THTTPWorkPool.SetOnBeforeRequest(const Value: THTTPJobRequestEvent);
begin
  FOnBeforeRequest := Value;
end;

procedure THTTPWorkPool.SetOnError(const Value: THTTPJobRequestEvent);
begin
  FOnError := Value;
end;

procedure THTTPWorkPool.SetOnSuccess(const Value: THTTPJobRequestEvent);
begin
  FOnSuccess := Value;
end;

procedure THTTPWorkPool.SetRequestsPerSecond(const Value: Cardinal);
begin
  FRequestsPerSecond := Value;
end;

procedure THTTPWorkPool.SetWorkerCount(const Value: THTTPWorkerCount);
begin
  FWorkerCount := Value;
end;

end.


