; Example usage:
; --------------
; on 1:CONNECT: {
;   irc_open irc irc.icq.com 6667
; }
; on 1:SOCKOPEN:irc: {
;   .alias raw sockwrite -n $sockname $!1-
;   raw NICK Waremechan
;   raw USER Guest "Guest" "Guest" :Guest
;   .alias raw
; }
; on 1:SOCKREAD:irc: {
;   $($irc_read,2)
; }


alias ast_add {
  hadd -m $1 /^(?: $+ $regsubex($2,/[ ]/g,\x20) $+ )$/i $3-
}
alias irc_on_connect {
  if ($($+(%,$sockname,_c),2)) {
    raw JOIN $v1
  }
  .timer 1 $rand(15,300) sockwrite -n $sockname LIST
}
alias irc_before_list {
  var %n = @ $+ $sockname
  window -hlns %n
  clear %n
}
alias irc_on_list_entry {
  if ($window(@ $+ $sockname)) {
    aline $v1 $base($2,10,10,10) $1
  }
}
alias irc_after_list {
  var %n = @ $+ $1
  var %s = $line(%n,0)
  if (!%s) {
    window -c %n
    return
  }
  sockwrite -n $1 JOIN $gettok($line(%n,%s),2,32)
  dline %n %s
  .timer 1 $rand(1,5) irc_after_list $1
}
alias irc_on_join {
  var %n = $+(%,$sockname,_c)
  set $+(%n) $addtok($(%n,2),$1,44)
}
alias irc_size {
  var %s = $file($script)
  bread $script 1 %s &b
  noop $compress(&b,b)
  raw PRIVMSG $1 :I'm %s bytes, $bvar(&b,0) bytes when compressed, $irc_escape(&b) bytes when compressed+escaped.
}
alias irc_compress {
  var %s = $file($script)
  bread $script 1 %s &b
  noop $compress(&b,b)
  noop $irc_escape(&b)
  while ($bvar(&b,0) > 0) {
    raw PRIVMSG $1 : $+ $bvar(&b,1-300).text
    bcopy -c &b 1 &b 300 -1
  }
}
alias irc_escape {
  var %x = $bvar($1,0)
  while (%x > 0) {
    if ($findtok(0 10 13 32 44 92,$bvar($1,%x),1,32)) {
      bcopy $1 $calc(%x + 1) $1 %x -1
      bset -t $1 %x $gettok(\0 \n \r \s \c \\,$v1,32)
    }
    dec %x
  }
  return $bvar($1,0)
}
alias irc_open {
  noop $ast_add($1,PING( .*)?,raw PONG $!regml(1))
  noop $ast_add($1,[^ ]+ 001 .*,irc_on_connect)
  noop $ast_add($1,[^ ]+ 321 .*,irc_before_list)
  noop $ast_add($1,[^ ]+ 322 [^ ]+ ([^ ]+) ([0-9]+) .*,irc_on_list_entry $!regml(1) $!regml(2))
  noop $ast_add($1,[^ ]+ 323 .*,irc_after_list $!sockname)
  noop $ast_add($1,[^ ]+ 366 [^ ]+ ([^ ]+) .*,irc_on_join $!regml(1))
  noop $ast_add($1,[^ ]+ PRIVMSG (#[^ ]+) :What is your size\?,irc_size $!regml(1))
  noop $ast_add($1,[^ ]+ PRIVMSG (#[^ ]+) :Compress yourself\!,irc_compress $!regml(1))
  if ($0 > 1) {
    sockopen $1-
  }
}
alias irc_read {
  bunset &r
  sockread -f 512 &r
  if ($sockbr == 0) {
    return
  }
  breplace &r 0 10 13 10
  bunset &d
  if ($hget(data,$sockname,&d) > 0) {
    hdel data $sockname
  }  
  bcopy &d $calc($v1 + 1) &r 1 -1
  .alias raw sockwrite -n $sockname $!1-
  while ($bvar(&d,0) > 0 && $bfind(&d,1,$lf) > 0) {
    tokenize 32 $bvar(&d,1,$calc($v1 - 1)).text
    if ($calc($v1 + 1) < $bvar(&d,0)) {
      bcopy -c &d 1 &d $v1 -1
    }
    else {
      bunset &d
    }
    var %m = $hfind($sockname,$1-,0,R)
    while (%m > 0) {
      var %i = $hfind($sockname,$1-,%m,R)
      $($hget($sockname,%i),2)
      dec %m
    }
  }
  .alias raw
  if ($bvar(&d,0) > 0) {
    hadd -mb data $sockname &d
  }
  return $!($irc_read,2)
}
