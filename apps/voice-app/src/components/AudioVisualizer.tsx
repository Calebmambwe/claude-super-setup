"use client";

import { useEffect, useRef } from "react";

interface AudioVisualizerProps {
  stream: MediaStream | null;
  isActive: boolean;
  className?: string;
}

export function AudioVisualizer({ stream, isActive, className = "" }: AudioVisualizerProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animationRef = useRef<number>(0);
  const analyserRef = useRef<AnalyserNode | null>(null);

  useEffect(() => {
    if (!stream || !isActive || !canvasRef.current) return;

    const audioContext = new AudioContext();
    const analyser = audioContext.createAnalyser();
    analyser.fftSize = 256;
    analyser.smoothingTimeConstant = 0.8;
    analyserRef.current = analyser;

    const source = audioContext.createMediaStreamSource(stream);
    source.connect(analyser);

    const canvas = canvasRef.current;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const bufferLength = analyser.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);

    function draw() {
      if (!ctx || !canvasRef.current || !analyserRef.current) return;

      animationRef.current = requestAnimationFrame(draw);

      const width = canvasRef.current.width;
      const height = canvasRef.current.height;

      analyserRef.current.getByteFrequencyData(dataArray);

      ctx.clearRect(0, 0, width, height);

      const barCount = 32;
      const barWidth = width / barCount - 2;
      const centerY = height / 2;

      for (let i = 0; i < barCount; i++) {
        const dataIndex = Math.floor((i / barCount) * bufferLength);
        const value = dataArray[dataIndex] / 255;
        const barHeight = Math.max(2, value * centerY * 0.9);

        const hue = 220 + i * 2;
        const alpha = 0.4 + value * 0.6;
        ctx.fillStyle = `hsla(${hue}, 80%, 65%, ${alpha})`;

        const x = i * (barWidth + 2);
        // Draw mirrored bars from center
        ctx.fillRect(x, centerY - barHeight, barWidth, barHeight);
        ctx.fillRect(x, centerY, barWidth, barHeight);
      }
    }

    draw();

    return () => {
      cancelAnimationFrame(animationRef.current);
      audioContext.close();
    };
  }, [stream, isActive]);

  // Idle animation when not active
  useEffect(() => {
    if (isActive || !canvasRef.current) return;

    const canvas = canvasRef.current;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let frame = 0;
    function drawIdle() {
      if (!ctx || !canvasRef.current) return;
      animationRef.current = requestAnimationFrame(drawIdle);

      const width = canvasRef.current.width;
      const height = canvasRef.current.height;
      const centerY = height / 2;

      ctx.clearRect(0, 0, width, height);

      const barCount = 32;
      const barWidth = width / barCount - 2;

      for (let i = 0; i < barCount; i++) {
        const wave = Math.sin(frame * 0.02 + i * 0.3) * 0.15 + 0.15;
        const barHeight = Math.max(2, wave * centerY * 0.3);

        ctx.fillStyle = `hsla(220, 40%, 45%, 0.3)`;
        const x = i * (barWidth + 2);
        ctx.fillRect(x, centerY - barHeight, barWidth, barHeight);
        ctx.fillRect(x, centerY, barWidth, barHeight);
      }
      frame++;
    }

    drawIdle();
    return () => cancelAnimationFrame(animationRef.current);
  }, [isActive]);

  return (
    <canvas
      ref={canvasRef}
      width={320}
      height={120}
      className={`rounded-lg ${className}`}
    />
  );
}
