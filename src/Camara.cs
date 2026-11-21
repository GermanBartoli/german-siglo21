using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Linq;
using System.Runtime.InteropServices;
using Windows.Foundation;
using Windows.Storage.Streams;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Windows.Graphics.Imaging;
using Windows.Media.Capture;
using Windows.Media.Capture.Frames;
using Windows.Media.MediaProperties;

public static class CamaraSiglo21
{
    public static void Mostrar()
    {
        using (var ventana = new Form())
        using (var vista = new PictureBox())
        using (var limite = new CancellationTokenSource(TimeSpan.FromSeconds(25)))
        {
            Exception error = null;
            bool completa = false;
            ventana.Text = "Comprobando la cámara";
            ventana.ClientSize = new Size(640, 480);
            ventana.StartPosition = FormStartPosition.CenterScreen;
            ventana.TopMost = true;
            vista.Dock = DockStyle.Fill;
            vista.BackColor = Color.Black;
            vista.SizeMode = PictureBoxSizeMode.Zoom;
            ventana.Controls.Add(vista);
            ventana.FormClosing += (s, e) => {
                if (!completa) { e.Cancel = true; limite.Cancel(); }
            };
            ventana.Shown += async (s, e) => {
                try { await VerVideo(vista, limite.Token); }
                catch (Exception ex) { error = ex; }
                finally { completa = true; ventana.Close(); }
            };
            ventana.ShowDialog();
            if (vista.Image != null) vista.Image.Dispose();
            if (error != null) throw new InvalidOperationException("No se completó la prueba de cámara. " + error.Message, error);
        }
    }

    private static async Task Esperar(IAsyncInfo tarea, CancellationToken limite)
    {
        try {
            while (tarea.Status == AsyncStatus.Started) await Task.Delay(50, limite);
            limite.ThrowIfCancellationRequested();
        } catch (OperationCanceledException) { tarea.Cancel(); throw; }
    }
    private static async Task VerVideo(PictureBox vista, CancellationToken limite)
    {
        using (var camara = new MediaCapture())
        {
            var opciones = new MediaCaptureInitializationSettings {
                StreamingCaptureMode = StreamingCaptureMode.Video,
                SharingMode = MediaCaptureSharingMode.SharedReadOnly,
                MemoryPreference = MediaCaptureMemoryPreference.Cpu
            };
            var inicio = camara.InitializeAsync(opciones);
            await Esperar(inicio, limite);
            inicio.GetResults();
            var fuente = camara.FrameSources.Values.Where(f => f.Info.SourceKind == MediaFrameSourceKind.Color)
                .OrderByDescending(f => f.Info.MediaStreamType == MediaStreamType.VideoPreview).FirstOrDefault();
            if (fuente == null) throw new InvalidOperationException("Windows no ofrece una fuente de video en color.");
            var crear = camara.CreateFrameReaderAsync(fuente, MediaEncodingSubtypes.Bgra8);
            await Esperar(crear, limite);
            using (var lector = crear.GetResults())
            {
                var iniciar = lector.StartAsync();
                await Esperar(iniciar, limite);
                if (iniciar.GetResults() != MediaFrameReaderStartStatus.Success)
                    throw new InvalidOperationException("Windows no pudo iniciar la cámara.");
                var visible = new Stopwatch();
                var sinImagen = Stopwatch.StartNew();
                byte[] pixeles = null;
                Windows.Storage.Streams.Buffer buffer = null;
                while (true) {
                    limite.ThrowIfCancellationRequested();
                    if (visible.IsRunning && sinImagen.ElapsedMilliseconds > 1500)
                        throw new InvalidOperationException("La cámara dejó de entregar imágenes.");
                    using (var cuadro = lector.TryAcquireLatestFrame())
                    using (var mapa = cuadro == null || cuadro.VideoMediaFrame == null ? null : cuadro.VideoMediaFrame.SoftwareBitmap)
                    {
                        if (mapa != null) {
                            int ancho = mapa.PixelWidth, alto = mapa.PixelHeight;
                            int cantidad = checked(ancho * alto * 4);
                            if (pixeles == null || pixeles.Length != cantidad) {
                                pixeles = new byte[cantidad];
                                buffer = new Windows.Storage.Streams.Buffer((uint)cantidad);
                            }
                            mapa.CopyToBuffer(buffer);
                            using (var datosImagen = DataReader.FromBuffer(buffer)) datosImagen.ReadBytes(pixeles);
                            var imagen = vista.Image as Bitmap;
                            if (imagen == null || imagen.Width != ancho || imagen.Height != alto) {
                                vista.Image = new Bitmap(ancho, alto, PixelFormat.Format32bppRgb);
                                if (imagen != null) imagen.Dispose();
                                imagen = (Bitmap)vista.Image;
                            }
                            var datos = imagen.LockBits(new Rectangle(0, 0, ancho, alto), ImageLockMode.WriteOnly, PixelFormat.Format32bppRgb);
                            try { Marshal.Copy(pixeles, 0, datos.Scan0, cantidad); }
                            finally { imagen.UnlockBits(datos); }
                            vista.Refresh();
                            sinImagen.Restart();
                            visible.Start();
                            if (visible.ElapsedMilliseconds >= 5000) break;
                        }
                    }
                    await Task.Delay(80, limite);
                }
                using (var plazo = new CancellationTokenSource(TimeSpan.FromSeconds(3))) {
                    var detener = lector.StopAsync();
                    await Esperar(detener, plazo.Token);
                    detener.GetResults();
                }
            }
        }
    }
}
