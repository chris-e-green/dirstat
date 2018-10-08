program dirstat2;
{ produces directory statistics for specified drive }
uses dos,crt,graph,drivers;
const
  progname = 'Directory Statistics';
  version  = '2.2';
  author   = 'C.E.Green';
  progid   = progname+' version '+version+' by '+author;
  distance = 10;    { distance in pixels from outside of pie }
  pratio1 = 1.2;  { divisor for distance of outer % from centre }
  pratio2 = 1.7;  { divisor for distance of inner % from centre }
  pratio3 = 3.0;
  centremin = -10; { range of h & v pixels from centre to center }
  centremax = 10;  { text within }
  width     = 4;   { formatting options for percentages }
  decimals  = 1;
  maxfill   = 11;

type
  dispmodetype = (text,graf);
  statmodetype = (disk,usedspace,subdir);
  sizemodetype = (val,percentage);
  listmodetype = (paused,nonpaused);
  listptr  = ^listrec;
  listrec  = record
                  next : listptr;
                  dir  : string;
                  size : longint;
                  x,
                  y    : integer;
                  color : word;
                  level : integer;
               end;
var
  list : listptr;
  pposition,
  lposition: boolean; { true=near edge,false=away from edge }
  pth : string;
  xa,
  ya     : word;
  sizemode : sizemodetype;
  statmode : statmodetype;
  dispmode : dispmodetype;
  listmode : listmodetype;
  radius,
  centrex,centrey:integer;
  stangle : real;
  count,
  chcount : integer;
  pstr   : string;
  dsize  : longint;
  free   : longint;
  used   : longint;
  comparitor : longint;
  stpath : string;
  total  : longint;
  percent:string;
  drvno : byte;
  i : byte;

procedure Abort (msg:string;errorlvl :byte);
begin
  writeln (msg);
  halt (errorlvl);
end;

procedure invalidparam;
begin
    writeln ('USAGE: DIRSTAT [drive_letter][:][path] [switches]');
    writeln;
    writeln ('  Proportion switches -');
    writeln ('  /U - display as proportion of used disk space (default)');
    writeln ('  /D - display as proportion of total disk space');
    writeln ('  /S - display as proportion of specified directory');
    writeln ('  If a path is specified, /S becomes the default.');
    writeln;
    writeln ('  Mode and mode-specific switches -');
    writeln ('  /T - display directories in text mode (default)');
    writeln ('  in text mode,  /P - pause after each page (default)');
    writeln ('  in text mode,  /N - don''t pause in output');
    writeln ('  /G - display directories as graphic pie chart');
    writeln ('  in graphics mode,  /B - display file sizes in bytes');
    writeln ('  in graphics mode,  /% - display file sizes as percentages(default)');
    writeln;
    writeln (
    'If no path or drive is specified, the current directory is selected.');
    Abort('',1);
end;

procedure writedirs (comparitor : longint;listmode:listmodetype);
var
  lp : listptr;
  temp : longint;
  sizestr : string;
  linecount: integer;
  tempstr:string;
  tempstr1:string;
  count : byte;
procedure checkedwrite (lstr:string;var linecount:integer);
var
  dummy:char;
begin
  writeln (lstr);
  if listmode = paused then begin
    linecount := linecount+1;
    if linecount = 23 then begin
      writeln ('Press a key to continue listing');
      while not keypressed do;
      dummy := readkey;
      linecount:=0;
    end;
  end;
end;

begin
  linecount := 0;
  lp := list;
  while lp <> NIL do begin
    if lp^.level <= 2 then checkedwrite('',linecount);
    temp := lp^.size;
    str(temp:8,sizestr);
    if temp > 1024 then begin
      temp := temp div 1024;
      str(temp:8,sizestr);
      sizestr := sizestr + 'K';
    end;
    str(lp^.size/comparitor*100:width:decimals,tempstr);
    tempstr1:=' ';
    for count := 1 to lp^.level do tempstr1:=' '+tempstr1;
    checkedwrite (tempstr+'% '+ sizestr+tempstr1+lp^.dir,linecount);
    lp := lp^.next;
  end;
end;

procedure plotgraph (comparitor : longint);
var
  stagger : byte;
  lp : listptr;
  start : real;
  inc   : real;
  currfill  : word;
  currcolor : word;
  x,y :integer;
  h,v :word;

begin
  stagger := 0;
  currfill := 1;
  currcolor := 1;
  lp := list;
  start :=0;
  while lp <> NIL do begin
    if lp^.level <= 2 then begin
      setcolor(currcolor);
      lp^.color := currcolor;
      SetFillStyle(CurrFill,CurrColor);
      inc := lp^.size / comparitor * 360;
      if round(start) < round (start+inc) then
        pieslice (centrex,centrey,round(start),round(start+inc),radius);
      if round(inc) <> 0 then begin
        currfill :=(currfill mod (maxfill-2))+1;
        if getmaxcolor > 1 then
          currcolor:=(currcolor mod (getmaxcolor-2))+1;
        x := round((radius+distance) * cos ((inc / 2+start)*pi/180));
        y := round((radius+distance) * sin ((inc / 2+start)*pi/180));
        case stagger of
        0 : begin
              lp^.x := round(x/pratio1+centrex);
              lp^.y := centrey-round(xa/ya*y/pratio1);
            end;
        1 : begin
              lp^.x := round(x/pratio2+centrex);
              lp^.y := centrey-round(xa/ya*y/pratio2);
            end;
        2 : begin
              lp^.x := round(x/pratio3+centrex);
              lp^.y := centrey-round(xa/ya*y/pratio3);
            end;
        end;
        stagger := (stagger + 1) mod 3;
        if x < centremin then h:=righttext else
        if x > centremax then h:=lefttext else h:=centertext;
        if y < centremin then v:=toptext else
        if y > centremax then v:=bottomtext else v:=centertext;
        settextjustify(h,v);
        outtextxy (x+centrex,centrey-round(xa/ya*y),lp^.dir);
      end
      else begin
        lp^.x := 0;
        lp^.y := 0;
      end;
      start := start + inc;
    end;
    lp := lp^.next;
  end;
end;

procedure plotpercent (comparitor : longint);
var
  boxl,
  boxw : byte;
  temp :longint;
  lp : listptr;
  perc : string;
begin
  SetFillStyle(SolidFill,Black);
  lp := list;
  while lp <> nil do begin
    if (lp^.level <= 2) and ((lp^.x <> 0) or (lp^.y <> 0)) then begin
      setcolor (lp^.color);
      settextjustify (centertext,centertext);
      if sizemode = percentage then begin
        if trunc(lp^.size/comparitor*1000)=0 then perc:='' else begin
          str(lp^.size/comparitor*100:width:decimals,perc);
          perc:=perc+'%';
        end;
      end else begin
        temp := lp^.size;
        str(temp:8,perc);
        if temp > 1024 then begin
          temp := temp div 1024;
          str(temp:8,perc);
          perc := perc + 'K';
        end;
      end;
      while perc[1] = ' ' do delete (perc,1,1);
      if perc <> '' then begin
        boxw := round(TextWidth(perc)/1.5);
        boxl := round(TextHeight(perc));
        FillEllipse(lp^.x,lp^.y,boxw,boxl);
        outtextxy (lp^.x,lp^.y,perc);
      end;
    end;
    lp := lp^.next;
  end;
end;

procedure calcfree;
var
  lp : listptr;
begin
  new(lp);
  lp^.next := list;
  lp^.dir  := 'Free';
  lp^.size := free;
  lp^.level:= 1;
  list := lp;
end;

procedure calcslack;
var
  lp : listptr;
begin
  new(lp);
  lp^.next := list;
  if pth = '' then lp^.dir  := 'Slack Space'
  else lp^.dir := 'Slack Space + Other';
  lp^.size := used-total;
  lp^.level:= 1;
  list := lp;
end;

procedure searchforfiles (spath:string;var total:longint;level:integer);
var
  v,h : word;
  x,y : integer;
  fsize : longint;
  f : searchrec;
  ltot : longint;
  drvno : byte;
  proportion : integer;
  listcur : listptr;
  l1tot : longint;
  percent : string;

begin
  ltot := 0;
  l1tot := 0;
  FindFirst (spath+'\*.*',anyfile,f);
  while doserror = 0 do begin
    fsize := f.size;
    if level = 1 then l1tot := l1tot + fsize;
    if not (f.name[1] = '.') and ((f.attr and directory) <> 0)
     then searchforfiles (spath+'\'+f.name,fsize,level+1);
    ltot := ltot + fsize;
    FindNext (f);
  end;
  new (listcur);
  listcur^.next := list;
  listcur^.dir  := spath;
  if level=1 then begin
    listcur^.size := l1tot;
    listcur^.dir := listcur^.dir + '\'
  end else listcur^.size := ltot;
  listcur^.level:= level;
  list := listcur;
  total := total + ltot;
end;

procedure parsedir (parameter:string;var drvno:byte; var pth:string);
var
  drv : char;

begin
  drv := upcase (parameter[1]);
  drvno := ord(drv)-ord('A')+1;
  if (drvno < 1) or (drvno > 26) then
    abort ('Drive letter must be between A and Z',2);
  pth := copy(parameter,3,length(parameter)-2);
  for i:=1 to length(pth) do pth[i]:=upcase(pth[i]);
  if copy(pth,length(pth),1)='\' then pth := copy(pth,1,length(pth)-1);
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
  centrex:=getmaxx div 2;
  centrey:=(getmaxy div 2);
  GetAspectRatio (xa,ya);
  radius:=round(centrey*ya/xa-36);
  SetBkColor(White);
  SetColor(Blue);
  SetTextJustify(CenterText,TopText);
  OutTextXY(centrex,3,progid+' for drive '+chr(drvno-1+ord('A'))+':');
  SetTextJustify(CenterText,BottomText);
  case statmode of
    disk : OutTextXY(centrex,getmaxy-3,'Directories as proportion of total disk space');
    usedspace : OutTextXY(centreX,getmaxy-3,'Directories as proportion of used disk space');
    subdir : OutTextXY(centreX,getmaxy-3,'Directories as a proportion of '+pth);
  end;
  SetTextStyle(DefaultFont,HorizDir,1);
end;

procedure stopgraf;
var
  dummy : char;
begin
  while not keypressed do;
  dummy := readkey;
  closegraph;
end;

begin
  writeln (progid);
  writeln;
  dispmode := text;
  statmode := usedspace;
  sizemode := percentage;
  listmode := paused;
  drvno := 99;
  pth := '';
  list := NIL;
  for count := 0 to paramcount do begin
   pstr := paramstr(count);
   chcount := 1;
   while chcount <= length(pstr) do begin
     if pstr[chcount] = '/' then begin
       case upcase(pstr[chcount+1]) of
         'D' : statmode := disk;
         'G' : dispmode := graf;
         'U' : statmode := usedspace;
         'T' : dispmode := text;
         'S' : statmode := subdir;
         'B' : sizemode := val;
         '%' : sizemode := percentage;
         'P' : listmode := paused;
         'N' : listmode := nonpaused;
       else
         InvalidParam;
       end; {case}
       delete(pstr,chcount,2);
       chcount := chcount - 1;
     end;
     chcount := chcount + 1;
   end;
   if (count > 0) and (length(pstr) > 0) then
     if pos(':',pstr) > 1 then
       if pos ('/',pstr) > 0 then
         parsedir(copy(pstr,1,pos('/',pstr)),drvno,pth)
       else
         parsedir(pstr,drvno,pth)
     else if drvno = 99 then begin { no directory }
       if copy(pstr,length(pstr),1)='\' then
         pstr := fexpand(pstr)
       else
         pstr:=fexpand(pstr+'\');
       pstr := copy (pstr,1,length(pstr)-1);
       parsedir(pstr,drvno,pth);
     end; { else if drvno }
  end; { for count}
  if drvno = 99 then begin { no directory }
    pstr := fexpand('');
    pstr := copy (pstr,1,length(pstr)-1);
    parsedir(pstr,drvno,pth);
  end;
  if pth <> '' then statmode := subdir;
  dsize := Disksize (drvno);
  if dsize = -1 then
    Abort ('ERROR : not reading a disk in drive '+chr(drvno-1+ord('A')),3);
  free := Diskfree(drvno);
  used := dsize-free;
  total := 0;
  stpath := chr(drvno-1+ord('A'))+':'+pth;
  stangle := 0;
  searchforfiles (stpath,total,1);
  case statmode of
    disk : comparitor := dsize;
    usedspace : comparitor := used;
    subdir : comparitor := total;
  end;
  if comparitor = 0 then
    abort ('ERROR : Directory '+chr(drvno-1+ord('A'))+':'+pth+' was not found or contained no files',6);
  if statmode = disk then calcfree;
  if statmode <> subdir then calcslack;
  if dispmode=graf then begin
    setupgraf(centrex,centrey,radius,xa,ya);
    plotgraph (comparitor);
    plotpercent(comparitor);
    stopgraf;
  end else writedirs (comparitor,listmode);
end. {program}
