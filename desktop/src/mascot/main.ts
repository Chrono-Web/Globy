// Finestra di Globy. Il globo arriva nella fase 3: per ora riceve le richieste.
import { listen } from "@tauri-apps/api/event";
import { commands } from "../shared/api";

listen("mascot-request", (event) => console.log("Globy", event.payload));
commands.mascotReady();
