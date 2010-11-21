unit hiRGN_Elliptic;

interface

uses Windows,Kol,Share,Debug;

type
  THIRGN_Elliptic = class(TDebug)
   private
    FRegion:HRGN;
   public
    _prop_Point1:integer;
    _prop_Point2:integer;
    _prop_Point2AsOffset:boolean;

    _data_Point2:THI_Event;
    _data_Point1:THI_Event;
    _event_onCreateElliptic:THI_Event;

    destructor Destroy; override;
    procedure _work_doCreateElliptic(var _Data:TData; Index:word);
    procedure _var_Result(var _Data:TData; Index:word);
  end;

implementation

destructor THIRGN_Elliptic.Destroy;
begin
   DeleteObject(FRegion);
   inherited;
end;

procedure THIRGN_Elliptic._work_doCreateElliptic;
var
   p1,p2:integer;
   x1,y1,x2,y2:integer;
begin
   p1 := ReadInteger(_Data, _data_Point1, _prop_Point1);
   p2 := ReadInteger(_Data, _data_Point2, _prop_Point2);
   x1 := p1 and $FFFF;
   y1 := p1 shr 16;
   if _prop_Point2AsOffset then
     begin
       x2 := x1;
       y2 := y1;
     end
   else
     begin
       x2 := 0;
       y2 := 0;
     end;
   inc(x2, p2 and $FFFF);
   inc(y2, p2 shr 16);
   DeleteObject(FRegion);
   FRegion := CreateEllipticRgn(x1, y1, x2, y2);
   _hi_onEvent(_event_onCreateElliptic, integer(FRegion));
end;

procedure THIRGN_Elliptic._var_Result;
begin
   dtInteger(_Data, FRegion);
end;

end.
