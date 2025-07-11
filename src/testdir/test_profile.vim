" Test Vim profiler

CheckFeature profile

source util/screendump.vim

if has('prof_nsec')
  let s:header = 'count     total (s)      self (s)'
  let s:header_func = 'count     total (s)      self (s)  function'
else
  let s:header = 'count  total (s)   self (s)'
  let s:header_func = 'count  total (s)   self (s)  function'
endif

func Test_profile_func()
  call RunProfileFunc('func', 'let', 'let')
  call RunProfileFunc('def', 'var', '')
endfunc

func RunProfileFunc(command, declare, assign)
  let lines =<< trim [CODE]
    profile start Xprofile_func.log
    profile func Foo*
    XXX Foo1()
    endXXX
    XXX Foo2()
      DDD counter = 100
      while counter > 0
        AAA counter = counter - 1
      endwhile
      sleep 1m
    endXXX
    XXX Foo3()
    endXXX
    XXX Bar()
    endXXX
    call Foo1()
    call Foo1()
    profile pause
    call Foo1()
    profile continue
    call Foo2()
    call Foo3()
    call Bar()
    if !v:profiling
      delfunc Foo2
    endif
    delfunc Foo3
  [CODE]

  call map(lines, {k, v -> substitute(v, 'XXX', a:command, '') })
  call map(lines, {k, v -> substitute(v, 'DDD', a:declare, '') })
  call map(lines, {k, v -> substitute(v, 'AAA', a:assign, '') })

  call writefile(lines, 'Xprofile_func.vim', 'D')
  call system(GetVimCommand()
    \ . ' -es --clean'
    \ . ' -c "so Xprofile_func.vim"'
    \ . ' -c "qall!"')
  call assert_equal(0, v:shell_error)

  sleep 50m
  let lines = readfile('Xprofile_func.log')

  " - Foo1() is called 3 times but should be reported as called twice
  "   since one call is in between "profile pause" .. "profile continue".
  " - Foo2() should come before Foo1() since Foo1() does much more work.
  " - Foo3() is not reported because function is deleted.
  " - Unlike Foo3(), Foo2() should not be deleted since there is a check
  "   for v:profiling.
  " - Bar() is not reported since it does not match "profile func Foo*".
  call assert_equal(31, len(lines))

  call assert_equal('FUNCTION  Foo1()',                            lines[0])
  call assert_match('Defined:.*Xprofile_func.vim:3',               lines[1])
  call assert_equal('Called 2 times',                              lines[2])
  call assert_match('^Total time:\s\+\d\+\.\d\+$',                 lines[3])
  call assert_match('^ Self time:\s\+\d\+\.\d\+$',                 lines[4])
  call assert_equal('',                                            lines[5])
  call assert_equal(s:header,                                      lines[6])
  call assert_equal('',                                            lines[7])
  call assert_equal('FUNCTION  Foo2()',                            lines[8])
  call assert_equal('Called 1 time',                               lines[10])
  call assert_match('^Total time:\s\+\d\+\.\d\+$',                 lines[11])
  call assert_match('^ Self time:\s\+\d\+\.\d\+$',                 lines[12])
  call assert_equal('',                                            lines[13])
  call assert_equal(s:header,                                     lines[14])
  call assert_match('^\s*1\s\+.*\s\(let\|var\) counter = 100$',    lines[15])
  call assert_match('^\s*101\s\+.*\swhile counter > 0$',           lines[16])
  call assert_match('^\s*100\s\+.*\s  \(let\)\= counter = counter - 1$', lines[17])
  call assert_match('^\s*10[01]\s\+.*\sendwhile$',                 lines[18])
  call assert_match('^\s*1\s\+.\+sleep 1m$',                       lines[19])
  call assert_equal('',                                            lines[20])
  call assert_equal('FUNCTIONS SORTED ON TOTAL TIME',              lines[21])
  call assert_equal(s:header_func,                                 lines[22])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Foo2()$',              lines[23])
  call assert_match('^\s*2\s\+\d\+\.\d\+\s\+Foo1()$',              lines[24])
  call assert_equal('',                                            lines[25])
  call assert_equal('FUNCTIONS SORTED ON SELF TIME',               lines[26])
  call assert_equal(s:header_func,                                 lines[27])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Foo2()$',              lines[28])
  call assert_match('^\s*2\s\+\d\+\.\d\+\s\+Foo1()$',              lines[29])
  call assert_equal('',                                            lines[30])

  call delete('Xprofile_func.log')
endfunc

func Test_profile_func_with_ifelse()
  call Run_profile_func_with_ifelse('func', 'let')
  call Run_profile_func_with_ifelse('def', 'var')
endfunc

func Run_profile_func_with_ifelse(command, declare)
  let lines =<< trim [CODE]
    XXX Foo1()
      if 1
        DDD x = 0
      elseif 1
        DDD x = 1
      else
        DDD x = 2
      endif
    endXXX
    XXX Foo2()
      if 0
        DDD x = 0
      elseif 1
        DDD x = 1
      else
        DDD x = 2
      endif
    endXXX
    XXX Foo3()
      if 0
        DDD x = 0
      elseif 0
        DDD x = 1
      else
        DDD x = 2
      endif
    endXXX
    call Foo1()
    call Foo2()
    call Foo3()
  [CODE]

  call map(lines, {k, v -> substitute(v, 'XXX', a:command, '') })
  call map(lines, {k, v -> substitute(v, 'DDD', a:declare, '') })

  call writefile(lines, 'Xprofile_func.vim', 'D')
  call system(GetVimCommand()
    \ . ' -es -i NONE --noplugin'
    \ . ' -c "profile start Xprofile_func.log"'
    \ . ' -c "profile func Foo*"'
    \ . ' -c "so Xprofile_func.vim"'
    \ . ' -c "qall!"')
  call assert_equal(0, v:shell_error)

  let lines = readfile('Xprofile_func.log')

  " - Foo1() should pass 'if' block.
  " - Foo2() should pass 'elseif' block.
  " - Foo3() should pass 'else' block.
  call assert_equal(57, len(lines))

  call assert_equal('FUNCTION  Foo1()',                            lines[0])
  call assert_match('Defined:.*Xprofile_func.vim',                 lines[1])
  call assert_equal('Called 1 time',                               lines[2])
  call assert_match('^Total time:\s\+\d\+\.\d\+$',                 lines[3])
  call assert_match('^ Self time:\s\+\d\+\.\d\+$',                 lines[4])
  call assert_equal('',                                            lines[5])
  call assert_equal(s:header,                                      lines[6])
  call assert_match('^\s*1\s\+.*\sif 1$',                          lines[7])
  call assert_match('^\s*1\s\+.*\s  \(let\|var\) x = 0$',          lines[8])
  call assert_match(        '^\s\+elseif 1$',                      lines[9])
  call assert_match(          '^\s\+\(let\|var\) x = 1$',          lines[10])
  call assert_match(        '^\s\+else$',                          lines[11])
  call assert_match(          '^\s\+\(let\|var\) x = 2$',          lines[12])
  call assert_match('^\s*1\s\+.*\sendif$',                         lines[13])
  call assert_equal('',                                            lines[14])
  call assert_equal('FUNCTION  Foo2()',                            lines[15])
  call assert_equal('Called 1 time',                               lines[17])
  call assert_match('^Total time:\s\+\d\+\.\d\+$',                 lines[18])
  call assert_match('^ Self time:\s\+\d\+\.\d\+$',                 lines[19])
  call assert_equal('',                                            lines[20])
  call assert_equal(s:header,                                      lines[21])
  call assert_match('^\s*1\s\+.*\sif 0$',                          lines[22])
  call assert_match(          '^\s\+\(let\|var\) x = 0$',          lines[23])
  call assert_match('^\s*1\s\+.*\selseif 1$',                      lines[24])
  call assert_match('^\s*1\s\+.*\s  \(let\|var\) x = 1$',          lines[25])
  call assert_match(        '^\s\+else$',                          lines[26])
  call assert_match(          '^\s\+\(let\|var\) x = 2$',          lines[27])
  call assert_match('^\s*1\s\+.*\sendif$',                         lines[28])
  call assert_equal('',                                            lines[29])
  call assert_equal('FUNCTION  Foo3()',                            lines[30])
  call assert_equal('Called 1 time',                               lines[32])
  call assert_match('^Total time:\s\+\d\+\.\d\+$',                 lines[33])
  call assert_match('^ Self time:\s\+\d\+\.\d\+$',                 lines[34])
  call assert_equal('',                                            lines[35])
  call assert_equal(s:header,                                      lines[36])
  call assert_match('^\s*1\s\+.*\sif 0$',                          lines[37])
  call assert_match(          '^\s\+\(let\|var\) x = 0$',          lines[38])
  call assert_match('^\s*1\s\+.*\selseif 0$',                      lines[39])
  call assert_match(          '^\s\+\(let\|var\) x = 1$',          lines[40])
  call assert_match('^\s*1\s\+.*\selse$',                          lines[41])
  call assert_match('^\s*1\s\+.*\s  \(let\|var\) x = 2$',          lines[42])
  call assert_match('^\s*1\s\+.*\sendif$',                         lines[43])
  call assert_equal('',                                            lines[44])
  call assert_equal('FUNCTIONS SORTED ON TOTAL TIME',              lines[45])
  call assert_equal(s:header_func,                                 lines[46])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Foo.()$',              lines[47])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Foo.()$',              lines[48])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Foo.()$',              lines[49])
  call assert_equal('',                                            lines[50])
  call assert_equal('FUNCTIONS SORTED ON SELF TIME',               lines[51])
  call assert_equal(s:header_func,                                 lines[52])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Foo.()$',              lines[53])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Foo.()$',              lines[54])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Foo.()$',              lines[55])
  call assert_equal('',                                            lines[56])

  call delete('Xprofile_func.log')
endfunc

func Test_profile_func_with_trycatch()
  call Run_profile_func_with_trycatch('func', 'let')
  call Run_profile_func_with_trycatch('def', 'var')
endfunc

func Run_profile_func_with_trycatch(command, declare)
  let lines =<< trim [CODE]
    XXX Foo1()
      try
        DDD x = 0
      catch
        DDD x = 1
      finally
        DDD x = 2
      endtry
    endXXX
    XXX Foo2()
      try
        throw 0
      catch
        DDD x = 1
      finally
        DDD x = 2
      endtry
    endXXX
    XXX Foo3()
      try
        throw 0
      catch
        throw 1
      finally
        DDD x = 2
      endtry
    endXXX
    call Foo1()
    call Foo2()
    let rethrown = 0
    try
      call Foo3()
    catch
      let rethrown = 1
    endtry
    if rethrown != 1
      " call Foo1 again so that the test fails
      call Foo1()
    endif
  [CODE]

  call map(lines, {k, v -> substitute(v, 'XXX', a:command, '') })
  call map(lines, {k, v -> substitute(v, 'DDD', a:declare, '') })

  call writefile(lines, 'Xprofile_func.vim', 'D')
  call system(GetVimCommand()
    \ . ' -es -i NONE --noplugin'
    \ . ' -c "profile start Xprofile_func.log"'
    \ . ' -c "profile func Foo*"'
    \ . ' -c "so Xprofile_func.vim"'
    \ . ' -c "qall!"')
  call assert_equal(0, v:shell_error)

  let lines = readfile('Xprofile_func.log')

  " - Foo1() should pass 'try' 'finally' blocks.
  " - Foo2() should pass 'catch' 'finally' blocks.
  " - Foo3() should not pass 'endtry'.
  call assert_equal(57, len(lines))

  call assert_equal('FUNCTION  Foo1()',                            lines[0])
  call assert_match('Defined:.*Xprofile_func.vim',                 lines[1])
  call assert_equal('Called 1 time',                               lines[2])
  call assert_match('^Total time:\s\+\d\+\.\d\+$',                 lines[3])
  call assert_match('^ Self time:\s\+\d\+\.\d\+$',                 lines[4])
  call assert_equal('',                                            lines[5])
  call assert_equal(s:header,                                      lines[6])
  call assert_match('^\s*1\s\+.*\stry$',                           lines[7])
  call assert_match('^\s*1\s\+.*\s  \(let\|var\) x = 0$',          lines[8])
  call assert_match(        '^\s\+catch$',                         lines[9])
  call assert_match(          '^\s\+\(let\|var\) x = 1$',          lines[10])
  call assert_match('^\s*1\s\+.*\sfinally$',                       lines[11])
  call assert_match('^\s*1\s\+.*\s  \(let\|var\) x = 2$',          lines[12])
  call assert_match('^\s*1\s\+.*\sendtry$',                        lines[13])
  call assert_equal('',                                            lines[14])
  call assert_equal('FUNCTION  Foo2()',                            lines[15])
  call assert_equal('Called 1 time',                               lines[17])
  call assert_match('^Total time:\s\+\d\+\.\d\+$',                 lines[18])
  call assert_match('^ Self time:\s\+\d\+\.\d\+$',                 lines[19])
  call assert_equal('',                                            lines[20])
  call assert_equal(s:header,                                      lines[21])
  call assert_match('^\s*1\s\+.*\stry$',                           lines[22])
  call assert_match('^\s*1\s\+.*\s  throw 0$',                     lines[23])
  call assert_match('^\s*1\s\+.*\scatch$',                         lines[24])
  call assert_match('^\s*1\s\+.*\s  \(let\|var\) x = 1$',          lines[25])
  call assert_match('^\s*1\s\+.*\sfinally$',                       lines[26])
  call assert_match('^\s*1\s\+.*\s  \(let\|var\) x = 2$',          lines[27])
  call assert_match('^\s*1\s\+.*\sendtry$',                        lines[28])
  call assert_equal('',                                            lines[29])
  call assert_equal('FUNCTION  Foo3()',                            lines[30])
  call assert_equal('Called 1 time',                               lines[32])
  call assert_match('^Total time:\s\+\d\+\.\d\+$',                 lines[33])
  call assert_match('^ Self time:\s\+\d\+\.\d\+$',                 lines[34])
  call assert_equal('',                                            lines[35])
  call assert_equal(s:header,                                      lines[36])
  call assert_match('^\s*1\s\+.*\stry$',                           lines[37])
  call assert_match('^\s*1\s\+.*\s  throw 0$',                     lines[38])
  call assert_match('^\s*1\s\+.*\scatch$',                         lines[39])
  call assert_match('^\s*1\s\+.*\s  throw 1$',                     lines[40])
  call assert_match('^\s*1\s\+.*\sfinally$',                       lines[41])
  call assert_match('^\s*1\s\+.*\s  \(let\|var\) x = 2$',          lines[42])
  call assert_match(        '^\s\+endtry$',                        lines[43])
  call assert_equal('',                                            lines[44])
  call assert_equal('FUNCTIONS SORTED ON TOTAL TIME',              lines[45])
  call assert_equal(s:header_func,                                 lines[46])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Foo.()$',              lines[47])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Foo.()$',              lines[48])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Foo.()$',              lines[49])
  call assert_equal('',                                            lines[50])
  call assert_equal('FUNCTIONS SORTED ON SELF TIME',               lines[51])
  call assert_equal(s:header_func,                                 lines[52])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Foo.()$',              lines[53])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Foo.()$',              lines[54])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Foo.()$',              lines[55])
  call assert_equal('',                                            lines[56])

  call delete('Xprofile_func.log')
endfunc

func Test_profile_file()
  let lines =<< trim [CODE]
    func! Foo()
    endfunc
    for i in range(10)
      " a comment
      call Foo()
    endfor
    call Foo()
  [CODE]

  call writefile(lines, 'Xprofile_file.vim', 'D')
  call system(GetVimCommandClean()
    \ . ' -es'
    \ . ' -c "profile start Xprofile_file.log"'
    \ . ' -c "profile file Xprofile_file.vim"'
    \ . ' -c "so Xprofile_file.vim"'
    \ . ' -c "so Xprofile_file.vim"'
    \ . ' -c "qall!"')
  call assert_equal(0, v:shell_error)

  let lines = readfile('Xprofile_file.log')

  call assert_equal(14, len(lines))

  call assert_match('^SCRIPT .*Xprofile_file.vim$',                   lines[0])
  call assert_equal('Sourced 2 times',                                lines[1])
  call assert_match('^Total time:\s\+\d\+\.\d\+$',                    lines[2])
  call assert_match('^ Self time:\s\+\d\+\.\d\+$',                    lines[3])
  call assert_equal('',                                               lines[4])
  call assert_equal(s:header,                                         lines[5])
  call assert_match('    2              0.\d\+ func! Foo()',          lines[6])
  call assert_equal('                            endfunc',            lines[7])
  " Loop iterates 10 times. Since script runs twice, body executes 20 times.
  " First line of loop executes one more time than body to detect end of loop.
  call assert_match('^\s*22\s\+\d\+\.\d\+\s\+for i in range(10)$',    lines[8])
  call assert_equal('                              " a comment',      lines[9])
  " if self and total are equal we only get one number
  call assert_match('^\s*20\s\+\(\d\+\.\d\+\s\+\)\=\d\+\.\d\+\s\+call Foo()$', lines[10])
  call assert_match('^\s*22\s\+\d\+\.\d\+\s\+endfor$',                lines[11])
  " if self and total are equal we only get one number
  call assert_match('^\s*2\s\+\(\d\+\.\d\+\s\+\)\=\d\+\.\d\+\s\+call Foo()$', lines[12])
  call assert_equal('',                                               lines[13])

  call delete('Xprofile_file.log')
endfunc

func Test_profile_file_with_cont()
  let lines = [
    \ 'echo "hello',
    \ '  \ world"',
    \ 'echo "foo ',
    \ '  \bar"',
    \ ]

  call writefile(lines, 'Xprofile_file.vim', 'D')
  call system(GetVimCommandClean()
    \ . ' -es'
    \ . ' -c "profile start Xprofile_file.log"'
    \ . ' -c "profile file Xprofile_file.vim"'
    \ . ' -c "so Xprofile_file.vim"'
    \ . ' -c "qall!"')
  call assert_equal(0, v:shell_error)

  let lines = readfile('Xprofile_file.log')
  call assert_equal(11, len(lines))

  call assert_match('^SCRIPT .*Xprofile_file.vim$',           lines[0])
  call assert_equal('Sourced 1 time',                         lines[1])
  call assert_match('^Total time:\s\+\d\+\.\d\+$',            lines[2])
  call assert_match('^ Self time:\s\+\d\+\.\d\+$',            lines[3])
  call assert_equal('',                                       lines[4])
  call assert_equal(s:header,                                 lines[5])
  call assert_match('    1              0.\d\+ echo "hello',  lines[6])
  call assert_equal('                              \ world"', lines[7])
  call assert_match('    1              0.\d\+ echo "foo ',   lines[8])
  call assert_equal('                              \bar"',    lines[9])
  call assert_equal('',                                       lines[10])

  call delete('Xprofile_file.log')
endfunc

" Test for ':profile stop' and ':profile dump' commands
func Test_profile_stop_dump()
  call delete('Xprof1.out')
  call delete('Xprof2.out')
  call delete('Xprof3.out')
  func Xprof_test1()
    return "Hello"
  endfunc
  func Xprof_test2()
    return "World"
  endfunc

  " Test for ':profile stop'
  profile start Xprof1.out
  profile func Xprof_test1
  call Xprof_test1()
  profile stop

  let lines = readfile('Xprof1.out')
  call assert_equal(17, len(lines))
  call assert_equal('FUNCTION  Xprof_test1()',                lines[0])
  call assert_match('Defined:.*test_profile.vim:',            lines[1])
  call assert_equal('Called 1 time',                          lines[2])
  call assert_match('^Total time:\s\+\d\+\.\d\+$',            lines[3])
  call assert_match('^ Self time:\s\+\d\+\.\d\+$',            lines[4])
  call assert_equal('',                                       lines[5])
  call assert_equal(s:header,                                 lines[6])
  call assert_match('^\s*1\s\+.*\sreturn "Hello"$',           lines[7])
  call assert_equal('',                                       lines[8])
  call assert_equal('FUNCTIONS SORTED ON TOTAL TIME',         lines[9])
  call assert_equal(s:header_func,                            lines[10])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Xprof_test1()$',  lines[11])
  call assert_equal('',                                       lines[12])
  call assert_equal('FUNCTIONS SORTED ON SELF TIME',          lines[13])
  call assert_equal(s:header_func,                            lines[14])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Xprof_test1()$',  lines[15])
  call assert_equal('',                                       lines[16])

  " Test for ':profile stop' for a different function
  profile start Xprof2.out
  profile func Xprof_test2
  call Xprof_test2()
  profile stop
  let lines = readfile('Xprof2.out')
  call assert_equal(17, len(lines))
  call assert_equal('FUNCTION  Xprof_test2()',                lines[0])
  call assert_match('Defined:.*test_profile.vim:',            lines[1])
  call assert_equal('Called 1 time',                          lines[2])
  call assert_match('^Total time:\s\+\d\+\.\d\+$',            lines[3])
  call assert_match('^ Self time:\s\+\d\+\.\d\+$',            lines[4])
  call assert_equal('',                                       lines[5])
  call assert_equal(s:header,                                 lines[6])
  call assert_match('^\s*1\s\+.*\sreturn "World"$',           lines[7])
  call assert_equal('',                                       lines[8])
  call assert_equal('FUNCTIONS SORTED ON TOTAL TIME',         lines[9])
  call assert_equal(s:header_func,                            lines[10])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Xprof_test2()$',  lines[11])
  call assert_equal('',                                       lines[12])
  call assert_equal('FUNCTIONS SORTED ON SELF TIME',          lines[13])
  call assert_equal(s:header_func,                            lines[14])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Xprof_test2()$',  lines[15])
  call assert_equal('',                                       lines[16])

  " Test for ':profile dump'
  profile start Xprof3.out
  profile func Xprof_test1
  profile func Xprof_test2
  call Xprof_test1()
  profile dump
  " dump the profile once and verify the contents
  let lines = readfile('Xprof3.out')
  call assert_equal(17, len(lines))
  call assert_match('^\s*1\s\+.*\sreturn "Hello"$',           lines[7])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Xprof_test1()$',  lines[11])
  call assert_match('^\s*1\s\+\d\+\.\d\+\s\+Xprof_test1()$',  lines[15])
  " dump the profile again and verify the contents
  call Xprof_test2()
  profile dump
  profile stop
  let lines = readfile('Xprof3.out')
  call assert_equal(28, len(lines))
  call assert_equal('FUNCTION  Xprof_test1()',                lines[0])
  call assert_match('^\s*1\s\+.*\sreturn "Hello"$',           lines[7])
  call assert_equal('FUNCTION  Xprof_test2()',                lines[9])
  call assert_match('^\s*1\s\+.*\sreturn "World"$',           lines[16])

  delfunc Xprof_test1
  delfunc Xprof_test2
  call delete('Xprof1.out')
  call delete('Xprof2.out')
  call delete('Xprof3.out')
endfunc

" Test for :profile sub-command completion
func Test_profile_completion()
  call feedkeys(":profile \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"profile continue dump file func pause start stop', @:)

  call feedkeys(":profile start test_prof\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('^"profile start.* test_profile\.vim', @:)

  call feedkeys(":profile file test_prof\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_match('"profile file test_profile\.vim', @:)
  call feedkeys(":profile file  test_prof\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_match('"profile file  test_profile\.vim', @:)
  call feedkeys(":profile file test_prof \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_match('"profile file test_prof ', @:)
  call feedkeys(":profile file X1B2C3\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_match('"profile file X1B2C3', @:)

  func Xprof_test()
  endfunc
  call feedkeys(":profile func Xprof\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"profile func Xprof_test', @:)
  call feedkeys(":profile   func   Xprof\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"profile   func   Xprof_test', @:)
  call feedkeys(":profile func Xprof \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"profile func Xprof ', @:)
  call feedkeys(":profile func X1B2C3\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"profile func X1B2C3', @:)

  call feedkeys(":profdel \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"profdel file func', @:)
  call feedkeys(":profdel  fu\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"profdel  func', @:)
  call feedkeys(":profdel he\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"profdel he', @:)
  call feedkeys(":profdel here \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"profdel here ', @:)
  call feedkeys(":profdel file test_prof\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"profdel file test_profile.vim', @:)
  call feedkeys(":profdel file  X1B2C3\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"profdel file  X1B2C3', @:)
  call feedkeys(":profdel func Xprof\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"profdel func Xprof_test', @:)
  call feedkeys(":profdel func Xprof_test  \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"profdel func Xprof_test  ', @:)
  call feedkeys(":profdel func  X1B2C3\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"profdel func  X1B2C3', @:)

  delfunc Xprof_test
endfunc

func Test_profile_errors()
  call assert_fails("profile func Foo", 'E750:')
  call assert_fails("profile pause", 'E750:')
  call assert_fails("profile continue", 'E750:')
  call assert_fails("profile stop", 'E750:')
  call assert_fails("profile dump", 'E750:')
endfunc

func Test_profile_truncate_mbyte()
  if &enc !=# 'utf-8'
    return
  endif

  let lines = [
    \ 'scriptencoding utf-8',
    \ 'func! Foo()',
    \ '  return [',
    \ '  \ "' . join(map(range(0x4E00, 0x4E00 + 340), 'nr2char(v:val)'), '') . '",',
    \ '  \ "' . join(map(range(0x4F00, 0x4F00 + 340), 'nr2char(v:val)'), '') . '",',
    \ '  \ ]',
    \ 'endfunc',
    \ 'call Foo()',
    \ ]

  call writefile(lines, 'Xprofile_file.vim', 'D')
  call system(GetVimCommandClean()
    \ . ' -es --cmd "set enc=utf-8"'
    \ . ' -c "profile start Xprofile_file.log"'
    \ . ' -c "profile file Xprofile_file.vim"'
    \ . ' -c "so Xprofile_file.vim"'
    \ . ' -c "qall!"')
  call assert_equal(0, v:shell_error)

  split Xprofile_file.log
  if &fenc != ''
    call assert_equal('utf-8', &fenc)
  endif
  /func! Foo()
  let lnum = line('.')
  call assert_match('^\s*return \[$', getline(lnum + 1))
  call assert_match("\u4F52$", getline(lnum + 2))
  call assert_match("\u5052$", getline(lnum + 3))
  call assert_match('^\s*\\ \]$', getline(lnum + 4))
  bwipe!

  call delete('Xprofile_file.log')
endfunc

func Test_profdel_func()
  let lines =<< trim [CODE]
    profile start Xprofile_file.log
    func! Foo1()
    endfunc
    func! Foo2()
    endfunc
    func! Foo3()
    endfunc

    profile func Foo1
    profile func Foo2
    call Foo1()
    call Foo2()

    profile func Foo3
    profdel func Foo2
    profdel func Foo3
    call Foo1()
    call Foo2()
    call Foo3()
  [CODE]
  call writefile(lines, 'Xprofile_file.vim', 'D')
  call system(GetVimCommandClean() . ' -es -c "so Xprofile_file.vim" -c q')
  call assert_equal(0, v:shell_error)

  let lines = readfile('Xprofile_file.log')
  call assert_equal(26, len(lines))

  " Check that:
  " - Foo1() is called twice (profdel not invoked)
  " - Foo2() is called once (profdel invoked after it was called)
  " - Foo3() is not called (profdel invoked before it was called)
  call assert_equal('FUNCTION  Foo1()',               lines[0])
  call assert_match('Defined:.*Xprofile_file.vim',    lines[1])
  call assert_equal('Called 2 times',                 lines[2])
  call assert_equal('FUNCTION  Foo2()',               lines[8])
  call assert_equal('Called 1 time',                  lines[10])
  call assert_equal('FUNCTIONS SORTED ON TOTAL TIME', lines[16])
  call assert_equal('FUNCTIONS SORTED ON SELF TIME',  lines[21])

  call delete('Xprofile_file.log')
endfunc

func Test_profdel_star()
  " Foo() is invoked once before and once after 'profdel *'.
  " So profiling should report it only once.
  let lines =<< trim [CODE]
    profile start Xprofile_file.log
    func! Foo()
    endfunc
    profile func Foo
    call Foo()
    profdel *
    call Foo()
  [CODE]
  call writefile(lines, 'Xprofile_file.vim', 'D')
  call system(GetVimCommandClean() . ' -es -c "so Xprofile_file.vim" -c q')
  call assert_equal(0, v:shell_error)

  let lines = readfile('Xprofile_file.log')
  call assert_equal(16, len(lines))

  call assert_equal('FUNCTION  Foo()',                lines[0])
  call assert_match('Defined:.*Xprofile_file.vim',    lines[1])
  call assert_equal('Called 1 time',                  lines[2])
  call assert_equal('FUNCTIONS SORTED ON TOTAL TIME', lines[8])
  call assert_equal('FUNCTIONS SORTED ON SELF TIME',  lines[12])

  call delete('Xprofile_file.log')
endfunc

" When typing the function it won't have a script ID, test that this works.
func Test_profile_typed_func()
  CheckScreendump

  let lines =<< trim END
      profile start XprofileTypedFunc
  END
  call writefile(lines, 'XtestProfile', 'D')
  let buf = RunVimInTerminal('-S XtestProfile', #{})

  call term_sendkeys(buf, ":func DoSomething()\<CR>"
	\ .. "echo 'hello'\<CR>"
	\ .. "endfunc\<CR>")
  call term_sendkeys(buf, ":profile func DoSomething\<CR>")
  call term_sendkeys(buf, ":call DoSomething()\<CR>")
  call TermWait(buf, 100)
  call StopVimInTerminal(buf)
  let lines = readfile('XprofileTypedFunc')
  call assert_equal("FUNCTION  DoSomething()", lines[0])
  call assert_equal("Called 1 time", lines[1])

  " clean up
  call delete('XprofileTypedFunc')
endfunc

func Test_vim9_profiling()
  " only tests that compiling and calling functions doesn't crash
  let lines =<< trim END
      vim9script
      def Func()
        Crash()
      enddef
      def Crash()
      enddef
      prof start Xprofile_crash.log
      prof func Func
      Func()
  END
  call writefile(lines, 'Xprofile_crash.vim', 'D')
  call system(GetVimCommandClean() . ' -es -c "so Xprofile_crash.vim" -c q')
  call assert_equal(0, v:shell_error)
  call assert_true(readfile('Xprofile_crash.log')->len() > 10)

  call delete('Xprofile_crash.log')
endfunc

func Test_vim9_nested_call()
  let lines =<< trim END
    vim9script
    var total = 0
    def One(Ref: func(number))
      for i in range(3)
        Ref(i)
      endfor
    enddef
    def Two(nr: number)
      total += nr
    enddef
    prof start Xprofile_nested.log
    prof func One
    prof func Two
    One((nr) => Two(nr))
    assert_equal(3, total)
  END
  call writefile(lines, 'Xprofile_nested.vim', 'D')
  call system(GetVimCommandClean() . ' -es -c "so Xprofile_nested.vim" -c q')
  call assert_equal(0, v:shell_error)

  let prof_lines = readfile('Xprofile_nested.log')->join('#')
  call assert_match('FUNCTION  <SNR>\d\+_One().*'
        \ .. '#Called 1 time.*'
        \ .. '#    1 \s*[0-9.]\+   for i in range(3)'
        \ .. '#    3 \s*[0-9.]\+ \s*[0-9.]\+     Ref(i)'
        \ .. '#    3 \s*[0-9.]\+   endfor', prof_lines)
  call assert_match('FUNCTION  <SNR>\d\+_Two().*'
        \ .. '#Called 3 times.*'
        \ .. '#    3 \s*[0-9.]\+   total += nr', prof_lines)

  call delete('Xprofile_nested.log')
endfunc


" vim: shiftwidth=2 sts=2 expandtab
