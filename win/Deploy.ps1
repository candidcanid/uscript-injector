param(
    [string]$ShareRoot
) 

echo "ShareRoot = $ShareRoot"
robocopy "$ShareRoot" C:\Modding\ProjectMirror /mir /XD "$ShareRoot\zig-cache" "$ShareRoot\reference" "$ShareRoot\notes" "$ShareRoot\src"
Start-Process "C:\Modding\ProjectMirror\zig-out\bin\payload_generator.exe" -Wait -WorkingDirectory "C:\Modding\ProjectMirror\win\CustomUDKSources" -NoNewWindow -PassThru
Start-Process "C:\Modding\ProjectMirror\zig-out\bin\uscript_bundler.exe" -Wait -WorkingDirectory "C:\Modding\ProjectMirror" -NoNewWindow -PassThru
