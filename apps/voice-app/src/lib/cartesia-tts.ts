/**
 * Cartesia Sonic Streaming Text-to-Speech Client
 *
 * Low-latency TTS that streams audio chunks for immediate playback.
 * Supports WebSocket streaming for sub-200ms first-byte latency.
 */

import { EventEmitter } from "events";

export interface CartesiaConfig {
  apiKey: string;
  voiceId?: string;
  model?: string;
  language?: string;
  sampleRate?: number;
  outputFormat?: "pcm_s16le" | "pcm_f32le" | "pcm_mulaw" | "pcm_alaw";
}

type CartesiaTTSEvent = {
  audio: [chunk: Uint8Array];
  done: [];
  error: [error: Error];
};

export class CartesiaTTS extends EventEmitter<CartesiaTTSEvent> {
  private config: Required<CartesiaConfig>;
  private ws: WebSocket | null = null;
  private contextId = "";

  constructor(config: CartesiaConfig) {
    super();
    this.config = {
      apiKey: config.apiKey,
      voiceId: config.voiceId ?? "a0e99841-438c-4a64-b679-ae501e7d6091", // Default Sonic voice
      model: config.model ?? "sonic-2",
      language: config.language ?? "en",
      sampleRate: config.sampleRate ?? 24000,
      outputFormat: config.outputFormat ?? "pcm_s16le",
    };
  }

  /**
   * Synthesize text to streaming audio via WebSocket.
   * Audio chunks are emitted as 'audio' events for immediate playback.
   */
  async synthesize(text: string): Promise<void> {
    this.contextId = crypto.randomUUID();

    return new Promise((resolve, reject) => {
      const url = `wss://api.cartesia.ai/tts/websocket?api_key=${this.config.apiKey}&cartesia_version=2024-06-10`;

      this.ws = new WebSocket(url);

      this.ws.onopen = () => {
        const request = {
          context_id: this.contextId,
          model_id: this.config.model,
          transcript: text,
          voice: {
            mode: "id",
            id: this.config.voiceId,
          },
          output_format: {
            container: "raw",
            encoding: this.config.outputFormat,
            sample_rate: this.config.sampleRate,
          },
          language: this.config.language,
        };
        this.ws!.send(JSON.stringify(request));
      };

      this.ws.onmessage = (event) => {
        try {
          const response = JSON.parse(event.data as string);

          if (response.type === "chunk") {
            const audioData = base64ToUint8Array(response.data);
            this.emit("audio", audioData);
          } else if (response.type === "done") {
            this.emit("done");
            this.ws?.close();
            resolve();
          } else if (response.type === "error") {
            const error = new Error(response.message ?? "Cartesia TTS error");
            this.emit("error", error);
            reject(error);
          }
        } catch {
          // ignore parse errors
        }
      };

      this.ws.onerror = () => {
        const error = new Error("Cartesia WebSocket error");
        this.emit("error", error);
        reject(error);
      };

      this.ws.onclose = () => {
        resolve();
      };
    });
  }

  /**
   * Synthesize text to audio using REST API (simpler, higher latency).
   * Returns complete audio buffer.
   */
  async synthesizeBuffer(text: string): Promise<ArrayBuffer> {
    const response = await fetch("https://api.cartesia.ai/tts/bytes", {
      method: "POST",
      headers: {
        "X-API-Key": this.config.apiKey,
        "Cartesia-Version": "2024-06-10",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model_id: this.config.model,
        transcript: text,
        voice: {
          mode: "id",
          id: this.config.voiceId,
        },
        output_format: {
          container: "raw",
          encoding: this.config.outputFormat,
          sample_rate: this.config.sampleRate,
        },
        language: this.config.language,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Cartesia API error ${response.status}: ${errorText}`);
    }

    return response.arrayBuffer();
  }

  cancel(): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(
        JSON.stringify({
          context_id: this.contextId,
          cancel: true,
        })
      );
      this.ws.close();
    }
  }
}

function base64ToUint8Array(base64: string): Uint8Array {
  const binaryString = atob(base64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}
