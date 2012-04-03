unit httppoolInterfaces;

interface

uses ActiveX, SuperObject;

const
  HTTPWORKER_JOB = 100;
  HTTPWORKER_JOB_BEFOREREQUEST = 101;
  HTTPWORKER_JOB_AFTERREQUEST = 102;
  HTTPWORKER_JOB_SUCCESS = 103;
  HTTPWORKER_JOB_ERROR = 104;

  BEFORE_REQUEST_ACTION_NONE = 0;
  // Do not process job
  BEFORE_REQUEST_ACTION_CANCEL = -1;
  // Push Job to end of queue
  BEFORE_REQUEST_ACTION_WAIT = 2;

  MAX_HTTPWORKERS = 4;

type
  IHTTPJobCallback = interface;

  IHTTPJob = interface
    ['{305D2914-8CFB-4325-BE47-0B19911CF094}']
    function ContentAsString: String; safecall;
    function ContentAsJSON: ISuperObject; safecall;
    function ContentAsStream: IStream; safecall;

    procedure SetMethod(const Value: String); safecall;
    procedure SetURL(const Value: String); safecall;
    procedure SetContentType(const Value: String); safecall;
    function getDataLength: Cardinal; safecall;
    function getDataPtr: Pointer; safecall;
    procedure SetTag(const Value: Integer);  safecall;
    function GetURL: String; safecall;
    procedure SetResultCode(const Value: Integer); safecall;
    function GetContentType: String; safecall;
    function GetMethod: String;  safecall;
    function GetResultCode: Integer;  safecall;
    function GetTag: Integer;  safecall;

    procedure SetCallback(const Value: IHTTPJobCallback);  safecall;
    procedure SetCookieText(const Value: String);  safecall;
    procedure SetHeaderText(const Value: String);  safecall;
    function GetCallback: IHTTPJobCallback; safecall;
    function GetCookieText: String; safecall;
    function GetHeaderText: String; safecall;

    property HeaderText: String read GetHeaderText write SetHeaderText;
    property CookieText: String read GetCookieText write SetCookieText;
    property Callback: IHTTPJobCallback read GetCallback write SetCallback;

    property URL: String read GetURL write SetURL;
    property Method: String read GetMethod write SetMethod;
    property ResultCode: Integer read GetResultCode write SetResultCode;

    property DataPtr: Pointer read getDataPtr;
    property DataLength: Cardinal read getDataLength;
    property ContentType: String read GetContentType write SetContentType;
    property Tag: Integer read GetTag write SetTag;

  end;

  IHTTPJobCallback = interface
    ['{D3FA7BC4-6CDE-45E4-94B9-262E60B799FA}']
    procedure OnError(AJob: IHTTPJob); safecall;
    procedure OnBeforeRequest(AJob: IHTTPJob; var AAction: Integer);safecall;
    procedure OnSuccess(AJob: IHTTPJob); safecall;
  end;

  IHTTPWorkPool = interface
    ['{F4CD10E0-9E6F-4090-A6EE-F90CC2388D1C}']
    function Job(AURL: String;
      const AMethod: String = 'GET';
      const AParam: String = '';
      const ACallback: IHTTPJobCallback = nil;
      const AHeaders: String = '';
      const ACookies: String = ''): IHTTPJob; safecall;

    function JobTagged(AURL: String;
      const AMethod: String = 'GET';
      const AParam: String = '';
      const ACallback: IHTTPJobCallback = nil;
      const ATag: Integer = 0;
      const AHeaders: String = '';
      const ACookies: String = ''): IHTTPJob; safecall;

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

  end;

implementation

end.
