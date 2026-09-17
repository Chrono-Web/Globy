<p align="center">
  <img src="Globy/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="128" height="128" alt="Icona di Globy">
</p>

<h1 align="center">Globy</h1>

<p align="center">
  I VOX di <a href="https://chronocol.com">Chronocol</a> sul tuo computer: a portata di clic e,<br>
  quando ne esce uno nuovo, con un piccolo globo che te lo legge.
</p>

<p align="center">
  <a href="https://github.com/Chrono-Web/Globy/releases/latest/download/Globy.dmg"><b>⬇ Scarica per Mac</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/Chrono-Web/Globy/releases/latest/download/Globy-Windows.exe"><b>⬇ Scarica per Windows</b></a>
  <br>
  <a href="https://github.com/Chrono-Web/Globy/releases/latest/download/Globy-Linux.deb"><b>⬇ Linux (.deb, ~4&nbsp;MB)</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/Chrono-Web/Globy/releases/latest/download/Globy-Linux.AppImage"><b>⬇ Linux (AppImage, ~78&nbsp;MB)</b></a>
  <br>
  <sub>Versione 0.2.0 · macOS 15+, Windows 10/11, Linux a 64 bit · gratuito e open source</sub>
  <br>
  <sub>Su Ubuntu, Debian e Mint preferisci il <b>.deb</b>. L'AppImage porta WebKit dentro e pesa di più.</sub>
  <br>
  <sub>🧪 Windows e Linux sono <b>in test</b>: se qualcosa non va, <a href="docs/SEGNALARE.md">segnalalo</a>.</sub>
</p>

## Installare

### Mac

1. Apri `Globy.dmg` e trascina Globy nella cartella **Applicazioni**.
2. Apri Globy. La prima volta il Mac lo blocca perché non è ancora firmato da Apple:
   vai in **Impostazioni di Sistema › Privacy e sicurezza** e premi **Apri comunque**.
3. Globy compare in alto nella barra dei menu e si presenta in basso a destra.

### Windows (in test)

1. Apri `Globy-Windows.exe`. Windows avvisa che l'app non è riconosciuta perché non è
   firmata: premi **Ulteriori informazioni** e poi **Esegui comunque**.
2. L'installazione non chiede permessi di amministratore.
3. Globy compare tra le icone vicino all'orologio (se non la vedi, apri la freccia **^**)
   e si presenta in basso a destra.

### Linux (in test)

1. **Ubuntu, Debian, Mint:** scarica `Globy-Linux.deb` (~4 MB) e aprilo con un doppio clic.
2. **Altre distro:** scarica `Globy-Linux.AppImage` (~78 MB), rendilo eseguibile
   (tasto destro › Proprietà › **Consenti l'esecuzione come programma**, oppure
   `chmod +x Globy-Linux.AppImage`) e aprilo con un doppio clic.
3. Globy compare tra le icone di sistema. Su GNOME serve l'estensione **AppIndicator**
   (su Ubuntu c'è già). Con Wayland il globo appare in una piccola finestra che il
   sistema posiziona da sé.

## Disinstallare

Apri **Impostazioni…** dall'icona di Globy › **Disinstalla Globy…**. Su Windows parte il
programma di disinstallazione; su Linux cancella poi il file AppImage, oppure
`sudo apt remove globy` se hai usato il `.deb`.

## Segnalare un problema

Qualcosa non funziona? Apri una [issue con il modulo «Problema»](https://github.com/Chrono-Web/Globy/issues/new?template=problema.yml):
la [guida](docs/SEGNALARE.md) spiega cosa scrivere.

---

Globy è in pre-alpha. Per capire com'è fatto o lavorarci c'è la
[guida alla documentazione](docs/GUIDA.md). Licenza [GNU GPL v3](LICENSE).
