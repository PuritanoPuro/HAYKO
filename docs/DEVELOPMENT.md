# Sviluppo

La copia di lavoro Git è la cartella HAYKO. La precedente cartella calcetto-mvp e i pacchetti di aggiornamento esterni non fanno parte del repository.

Prima di ogni commit eseguire i controlli nel README. Versionare pubspec.lock per rendere riproducibili le dipendenze dell'app. Per modifiche significative usare un branch e una pull request. Non caricare cache, build, backup o configurazioni private.

Android richiede Android SDK e toolchain configurati; iOS richiede macOS e Xcode. Su una copia appena clonata, flutter pub get prepara i file generati Flutter; flutter run/build prepara gli artefatti della piattaforma. Per una build release sono necessarie le configurazioni di firma del proprietario, che non sono incluse.

La pipeline verifica formattazione, analisi e test. Le build native, le notifiche su dispositivo, i deep link, l'autenticazione e le RPC del progetto Supabase vanno verificati separatamente nell'ambiente configurato.

La documentazione in history descrive versioni precedenti e può contenere percorsi o procedure superati. Non utilizzare i vecchi updater per modificare questa nuova struttura.
