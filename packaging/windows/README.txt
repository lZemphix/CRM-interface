CRM-interface — Windows 10/11 x64

Extract the ENTIRE CRM-interface directory before launching crm_interface.exe.
Keep the data directory, plugin DLLs and bundled Visual C++ runtime DLLs together.
Flutter, Dart and Visual Studio are not required on the receiving computer.
This is a portable development build, not a signed installer. Windows SmartScreen
may show a warning. Only use packages received from the project's trusted release.

Backend is distributed separately. The default API address is http://127.0.0.1:8000.
To connect to another server, open PowerShell in this directory and run:
  .\crm_interface.exe --api-url=https://crm.example.org
Replace the example address with your administrator's actual CRM server address.
Use HTTPS outside a trusted local development environment.

The application does not include accounts, passwords, tokens or database files.
Refresh tokens are stored in the operating system's secure storage after login.
The bundled Microsoft runtime libraries remain subject to Microsoft's terms.
