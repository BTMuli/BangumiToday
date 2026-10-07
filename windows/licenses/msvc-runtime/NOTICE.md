# Microsoft Visual C++ runtime

The four app-local CRT DLLs come from Microsoft's signed Visual C++
Redistributable 14.51.36231.0. The preparation script verifies the installer,
its embedded cabinets and each DLL against `dependencies.lock.json`, then
extracts the files without executing or installing the redistributable.

Source manifest:
https://github.com/microsoft/winget-pkgs/tree/master/manifests/m/Microsoft/VCRedist/2015%2B/x64/14.51.36231.0

Microsoft redistribution terms and app-local deployment guidance:
https://aka.ms/vs/18/redistribution
https://learn.microsoft.com/en-us/cpp/windows/local-app-deployment

The DLLs remain Microsoft redistributable code. Windows supplies the Universal
C Runtime (`ucrtbase.dll` and `api-ms-win-crt-*`); it is not bundled here.
