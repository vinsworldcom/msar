@echo off

del out.txt 2>nul

>  commands.txt echo ..\msar in.txt map.txt
>> commands.txt echo ..\msar in.txt map.txt -i
>> commands.txt echo ..\msar in.txt map.txt -c 1,3
>> commands.txt echo ..\msar in.txt map.txt -c 1,3 -i
>> commands.txt echo ..\msar in.txt map.txt -c 1,3 -i -a
>> commands.txt echo ..\msar in.txt map.txt -c 2-3
>> commands.txt echo ..\msar in.txt map.txt -c 2-3 -i
>> commands.txt echo ..\msar in.txt map.txt -c 2-3 -i -a
>> commands.txt echo ..\msar in.txt map.txt -r
>> commands.txt echo ..\msar in.txt map.txt -c 2-4 -r
>> commands.txt echo ..\msar book1.txt map.txt
>> commands.txt echo ..\msar book1.txt map.txt -i
>> commands.txt echo ..\msar book1.txt map.txt -i -a

for /f "tokens=*" %%i in (commands.txt) do @echo C: %%i >> out.txt && %%i >> out.txt && echo. >> out.txt

fc /n /t /l orig.txt out.txt > nul
if %ERRORLEVEL%==0 (echo OK) else fc /n /t /l orig.txt out.txt

del out.txt 2>nul
del commands.txt 2>nul
