unit Threads;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ComCtrls, System.Math, System.SyncObjs, Vcl.ExtCtrls,
  System.Types, System.Threading, System.Generics.Collections;

type
  ILogOperacoes = interface
    ['{F1DF1AB2-B0C6-40BB-9BB8-21F032ECE01A}']
    procedure EscreverMensagem(const AValue: string);
    procedure AtualizarProgresso(const ASender: TObject; const AValue: Integer);
  end;

  TListaThread = class(TThreadList<TThread>)
  strict private
    FOnNotifyItemTerminate: TProc<TThread>;
    procedure OnThreadTerminateHandler(Sender: TObject);
    procedure TerminateThread(const AThread: TThread);
    function GetCount(): Integer;
  public
    property Count: Integer read GetCount;
    property OnNotifyItemTerminate: TProc<TThread> read FOnNotifyItemTerminate write FOnNotifyItemTerminate;
    procedure Add(const AItem: TThread);
    procedure WithLockList(const AProc: TProc<TList<TThread>>);
    procedure TerminateAll();
  end;

  TfThreads = class(TForm, ILogOperacoes)
    labThreads: TLabel;
    edtNumero: TEdit;
    butIniciar: TButton;
    ProgressBar1: TProgressBar;
    mmoLog: TMemo;
    Label2: TLabel;
    edtIntervalo: TEdit;
    Label3: TLabel;
    procedure butIniciarClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    FThreadMonitoramento: TThread;
    FListaThread: TListaThread;
    function CriarThreadMonitaramento(): TThread;
  strict private
    { ILogOperacoes }
    procedure EscreverMensagem(const AValue: string);
    procedure AtualizarProgresso(const ASender: TObject; const AValue: Integer);
  strict private
    const
      MAX_PROGRESSO = 101;
  public
  end;

  TParametrosThread = record
  public
    IntervaloMaximo: Integer;
  end;

  TProcessoThread = class(TThread)
  strict private
    FLog: ILogOperacoes;
    FParametros: TParametrosThread;
    function ObterIntervalo(): Integer;
  strict protected
    procedure Execute(); override;
  public
    constructor Create(const ALog: ILogOperacoes; const AParametros: TParametrosThread);
    destructor Destroy(); override;
    class function New(const ALog: ILogOperacoes; const AParametros: TParametrosThread): TProcessoThread;
  end;

var
  fThreads: TfThreads;

implementation

{$R *.dfm}

procedure TfThreads.AtualizarProgresso(const ASender: TObject; const AValue: Integer);
begin
  TThread.Synchronize(nil,
  //TThread.Queue(nil,
    procedure()
    begin
      ProgressBar1.Position := ProgressBar1.Position + 1;
    end);
end;

procedure TfThreads.butIniciarClick(Sender: TObject);
var
  LParametros: TParametrosThread;
  LIndice: Integer;
  LNumeroThreads: Integer;
begin
  if (StrToIntDef(edtNumero.Text, 0) > 3000) then
    raise Exception.Create('O número máximo de threads é 3000');
  mmoLog.Clear();
  ProgressBar1.Position := 0;
  LNumeroThreads := StrToIntDef(edtNumero.Text, 0);
  butIniciar.Enabled := (LNumeroThreads = 0);
  try
    ProgressBar1.Max := LNumeroThreads * MAX_PROGRESSO;
    LParametros.IntervaloMaximo := StrToIntDef(edtIntervalo.Text, 0);
    for LIndice := 1 to LNumeroThreads do
    begin
      FListaThread.Add(TProcessoThread.New(Self, LParametros));
    end;
  except
    butIniciar.Enabled := True;
    raise;
  end;
end;

function TfThreads.CriarThreadMonitaramento(): TThread;
begin
  Result := TThread.CreateAnonymousThread(
    procedure()
    begin
      while (not TThread.CheckTerminated()) do
      begin
        TThread.Sleep(10);
        TThread.Synchronize(nil,
        //TThread.Queue(nil,
          procedure()
          var
            LCount: Integer;
          begin
            LCount := FListaThread.Count;
            labThreads.Caption := Format('Threads rodando %d', [LCount]);
            butIniciar.Enabled := (LCount = 0);
          end);
      end;
    end);
  Result.FreeOnTerminate := False;
end;

procedure TfThreads.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FListaThread.TerminateAll();
end;

procedure TfThreads.FormCreate(Sender: TObject);
begin
  FListaThread := TListaThread.Create();
  FListaThread.OnNotifyItemTerminate :=
    procedure(AThread: TThread)
    begin
      if Assigned(AThread.FatalException) then
      begin
        EscreverMensagem(Format('A Thread %d finalizou com uma exceção %s', [AThread.ThreadID, Exception(AThread.FatalException).Message]));
      end;
    end;
  FThreadMonitoramento := CriarThreadMonitaramento();
  FThreadMonitoramento.Start();
end;

procedure TfThreads.FormDestroy(Sender: TObject);
begin
  FThreadMonitoramento.Terminate();
  FThreadMonitoramento.WaitFor();
  FreeAndNil(FThreadMonitoramento);
  FListaThread.TerminateAll();
  FreeAndNil(FListaThread);
end;

procedure TfThreads.EscreverMensagem(const AValue: string);
begin
  TThread.Synchronize(nil,
  //TThread.Queue(nil,
    procedure()
    begin
      mmoLog.Lines.Add(Format('[%s] %s', [DateTimeToStr(Now()), AValue]));
    end);
end;

{ TProcessoThread }

constructor TProcessoThread.Create(const ALog: ILogOperacoes; const AParametros: TParametrosThread);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FLog := ALog;
  FParametros := AParametros;
end;

destructor TProcessoThread.Destroy();
begin
  inherited Destroy();
end;

procedure TProcessoThread.Execute();
var
  LProgresso: Integer;
begin
  Randomize();
  FLog.EscreverMensagem(Format('%d - Iniciando processamento', [ThreadID]));
  for LProgresso := 0 to 100 do
  begin
    if Terminated then
      Break;
    TThread.Sleep(ObterIntervalo());
    FLog.AtualizarProgresso(Self, LProgresso);
  end;
  FLog.EscreverMensagem(Format('%d - Processamento finalizado', [ThreadID]));
end;

class function TProcessoThread.New(const ALog: ILogOperacoes; const AParametros: TParametrosThread): TProcessoThread;
begin
  Result := TProcessoThread.Create(ALog, AParametros);
  Result.Start();
end;

function TProcessoThread.ObterIntervalo(): Integer;
begin
  Result := Random(FParametros.IntervaloMaximo);
end;

{ TListaThread<T> }

procedure TListaThread.Add(const AItem: TThread);
begin
  AItem.OnTerminate := OnThreadTerminateHandler;
  inherited Add(AItem);
end;

function TListaThread.GetCount(): Integer;
var
  LResult: Integer;
begin
  WithLockList(
    procedure(AList: TList<TThread>)
    begin
      LResult := AList.Count;
    end);
  Result := LResult;
end;

procedure TListaThread.TerminateAll();
begin
  WithLockList(
    procedure(AList: TList<TThread>)
    begin
      while (AList.Count > 0) do
      begin
        TerminateThread(AList.ExtractAt(0));
      end;
    end);
end;

procedure TListaThread.TerminateThread(const AThread: TThread);
begin
  AThread.FreeOnTerminate := False;
  AThread.Terminate();
  AThread.WaitFor();
  AThread.DisposeOf();
end;

procedure TListaThread.OnThreadTerminateHandler(Sender: TObject);
begin
  FOnNotifyItemTerminate(TThread(Sender));
  Remove(TThread(Sender));
end;

procedure TListaThread.WithLockList(const AProc: TProc<TList<TThread>>);
var
  LList: TList<TThread>;
begin
  LList := LockList();
  try
    AProc(LList);
  finally
    UnlockList();
  end;
end;

end.

