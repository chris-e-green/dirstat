program dirstat;
{ produces directory statistics for specified drive }
uses dos,graph,drivers;
const
  progname = 'Directory Statistics';
  version  = '1.7';
  author   = 'C.E.Green';
  progid   = progname+' version '+version+' by '+author;
  distance = 10;    { distance in pixels from outside of pie }
  pratio1 = 1.2;  { divisor for distance of outer % from centre }
  pratio2 = 1.3;  { divisor for distance of inner % from centre }
  centremin = -10; { range of h & v pixels from centre to center }
  centremax = 10;  { text within }
  width     = 3;   { formatting options for percentages }
  decimals  = 1;
  boxl      =25;
  boxw      =8;
  maxfill   = 11;

type
  dispmodetype = (text,graf);
  statmodetype = (disk,usedspace);
  percentptr  = ^percentlist;
  percentlist = record
                  perc : string;
                  x,
                  y    : integer;
                  color : word;
                  next : percentptr;
               end;
var
  percenttop : percentptr;
  percentcur : percentptr;
  pposition,
  lposition: boolean; { true=near edge,false=away from edge }

  pth : string;
  xa,
  ya     : word;
  statmode : statmodetype;
  dispmode : dispmodetype;
  radius,
  centrex,centrey:integer;
  stangle : real;
  count  : integer;
  pstr   : string;
  dsize  : longint;
  used   : longint;
  comparitor : longint;
  stpath : string;
  total  : longint;
  drvno  : byte;
  drv    : char;
  percent:string;
  currfill  : word;
  currcolor : word;

procedure Abort (msg:string;errorlvl :byte);
begin
  writeln (msg);
  halt (errorlvl);
end;

procedure invalidparam;
begin
    writeln ('USAGE: DIRSTAT drive_letter [/U][/D][/T][/G]');
    writeln;
    writeln ('  /U - display as proportion of used disk space (default)');
    writeln ('  /D - display as proportion of total disk space');
    writeln ('  /T - display directories in text mode (default)');
    writeln ('  /G - display directories as graphic pie chart');
    Abort('',1);
end;

procedure plotperc;
begin
  SetFillStyle(SolidFill,Black);
  while percentcur <> nil do begin
    setcolor (percentcur^.color);
    settextjustify (centertext,centertext);
    if percentcur^.perc <> '' then begin
      FillEllipse(percentcur^.x,percentcur^.y,boxl,boxw);
      outtextxy (percentcur^.x,percentcur^.y,percentcur^.perc);
    end;
    percentcur := percentcur^.next;
  end;
end;

procedure plotpie (var start:real;inc:real;tlabel,tpercent:string);
var
  h,v :word;
  x,y :integer;
  xp,yp:integer;
  xl:integer;
  p : percentptr;

begin
  setcolor(currcolor);
  SetFillStyle(CurrFill,CurrColor);
  pieslice (centrex,centrey,round(start),round(start+inc),radius);
  x := round((radius+distance) * cos ((inc / 2+start)*pi/180));
  xp := round(x / pratio1);
  y := round((radius+distance) * sin ((inc / 2+start)*pi/180));
  yp := round(y / pratio1);
  if not pposition then begin xp:=round(xp/pratio2);yp:=round(yp/pratio2);end;
  start := start + inc;
  if trunc(inc) <>0 then begin
    if x < centremin then h:=righttext else
      if x > centremax then h:=lefttext
      else h:=centertext;
  v:=bottomtext;
{    if y < centremin then v:=toptext else
      if y > centremax then v:=bottomtext
      else v:=centertext;}
{    if x < 0 then begin
      xl := round(x*1.7) ;
      h := lefttext;
    end else begin
      xl := centrex-3-x div 2;
      h := righttext;
    end;}
    settextjustify(h,v);
    outtextxy (x+centrex,centrey-round(xa/ya*y),tlabel);
{    settextjustify (centertext,centertext);
      SetFillStyle(SolidFill,Black);
      FillEllipse(xp+centrex,centrey-round(xa/ya*yp),boxl,boxw);
      outtextxy (xp+centrex,centrey-round(xa/ya*yp),tpercent);
    end;}
    if tpercent <> '' then pposition:=not pposition;
    new (p);
    p^.perc := tpercent;
    p^.x := xp+centrex;
    p^.y := centrey-round(xa/ya*yp);
    p^.color := currcolor;
    p^.next := percentcur;
    percentcur := p;
    currfill :=(currfill+1) mod (maxfill);
    if getmaxcolor > 1 then
     currcolor:=(currcolor+1) mod (getmaxcolor-1)+1;
  end;
end;

procedure searchforfiles (spath:string;var total:longint;level:integer;
                          var stangle:real);
var
  v,h : word;
  x,y : integer;
  fsize : longint;
  f : searchrec;
  ltot : longint;
  l1tot : longint;
  drvno : byte;
  proportion : integer;
  percent : string;

begin
  l1tot := 0;
  ltot := 0;
  FindFirst (spath+'\*.*',anyfile,f);
  while doserror = 0 do begin
    fsize := f.size;
    if level=1 then l1tot := l1tot+fsize;
    if not (f.name[1] = '.') and ((f.attr and directory) <> 0)
     then searchforfiles (spath+'\'+f.name,fsize,level+1,stangle);
    ltot := ltot + fsize;
    FindNext (f);
  end;
  if trunc(ltot/comparitor*1000)=0 then percent:='' else begin
    Str(ltot/comparitor*100:width:decimals,percent);
    percent := percent + '%';
  end;
  case dispmode of
    graf : begin
             if level = 2 then
               plotpie (stangle,ltot/comparitor*360,spath,percent);
             if level = 1 then begin
               if trunc (l1tot/comparitor*1000)=0 then percent:='' else begin
                 str (l1tot/comparitor*100:width:decimals,percent);
                 percent := percent+'%';
               end;
               plotpie (stangle,l1tot/comparitor*360,spath+'\',percent);
             end;
           end;
    text : begin
             writeln (percent,
                     ' ':level,spath,' ':(61-length(spath)-level),
                     ' = ',ltot:8);
             if level=2 then writeln;
           end;
    end;
  total := total + ltot;
end;

procedure setupgraf(var centrex,centrey,radius:integer;var xa,ya:word);
var
  driver,
  mode,
  error   : integer;
begin
  { Register all the drivers }
  if RegisterBGIdriver(@CGADriverProc) < 0 then
    Abort('Graphics Driver',5);
  if RegisterBGIdriver(@EGAVGADriverProc) < 0 then
    Abort('Graphics Driver',5);
  if RegisterBGIdriver(@HercDriverProc) < 0 then
    Abort('Graphics Driver',5);
  if RegisterBGIdriver(@ATTDriverProc) < 0 then
    Abort('Graphics Driver',5);
  if RegisterBGIdriver(@PC3270DriverProc) < 0 then
    Abort('Graphics Driver',5);
  driver := detect;
  initgraph (driver,mode,'');
  error := graphresult;
  if error <> grOk then
    Abort ('ERROR : graphics not available',4);
  CurrColor:=1;
  CurrFill:=1;
  pposition:=true;
  lposition:=false;
  centrex:=getmaxx div 2;
  centrey:=(getmaxy div 2);
  GetAspectRatio (xa,ya);
  radius:=round(centrey*ya/xa-36);
  SetBkColor(White);
  SetColor(Blue);
  SetTextJustify(CenterText,TopText);
  OutTextXY(centrex,3,progid+' for drive '+drv+':');
  SetTextJustify(CenterText,BottomText);
  if statmode=disk then OutTextXY(centrex,getmaxy-3,'Directories as proportion of total disk space')
  else OutTextXY(centreX,getmaxy-3,'Directories as proportion of used disk space');
  SetTextStyle(DefaultFont,HorizDir,1);
  new(percenttop);
  percenttop:=nil;
  percentcur:=percenttop;
end;

procedure stopgraf;
var
  dummy : char;
begin
  read (dummy);
  closegraph;
end;

begin
  writeln (progid);
  writeln;
  dispmode := text;
  statmode := usedspace;
  pth := '';
  if paramcount = 0 then InvalidParam;
  for count := 1 to paramcount do begin
   pstr := paramstr(count);
   if pstr[1] = '/' then
     case upcase(pstr[2]) of
       'D' : statmode := disk;
       'G' : dispmode := graf;
       'U' : statmode := usedspace;
       'T' : dispmode := text;
     else
       InvalidParam;
     end {case upcase}
   else
     if (length(pstr)= 1) or (pstr[2] = ':') then begin
       drv := upcase (pstr[1]);
       drvno := ord(drv)-ord('A')+1;
       if (drvno < 1) or (drvno > 26) then
         abort ('Drive letter must be between A and Z',2);
       pth := copy(pstr,3,length(pstr)-2);
     end; {if length}
   end; { for count}
  dsize := Disksize (drvno);
  if dsize = -1 then
    Abort ('ERROR : not reading a disk in drive '+drv,3);
  used := dsize-Diskfree(drvno);
  if statmode = disk then comparitor := dsize else comparitor := used;
  total := 0;
  stpath := drv+':'+pth;
  stangle := 0;
  if dispmode=graf then setupgraf(centrex,centrey,radius,xa,ya);
  searchforfiles (stpath,total,1,stangle);
  if dispmode=graf then begin
    if trunc((used-total)/comparitor*1000)=0 then percent:= '' else begin
      str((used-total)/comparitor*100:width:decimals,percent);
      percent:=percent+'%';
    end;
    if pth = '' then
    plotpie(stangle,(used-total)/comparitor*360,'Slack Space',percent)
    else
    plotpie(stangle,(used-total)/comparitor*360,'Other + Slack',percent);
    if statmode=disk then begin
      if trunc((dsize-used)/comparitor*1000)=0 then percent:='' else begin
        str((dsize-used)/comparitor*100:width:decimals,percent);
        percent:=percent+'%';
      end;
      plotpie(stangle,(dsize-used)/comparitor*360,'Free',percent);
    end;
    plotperc;
    stopgraf;
  end;
  if dispmode=text then
    writeln ('Slack space = ',used-total:8,' or ',
             (used-total)/comparitor*100:width:decimals,'%');
end. {program}
