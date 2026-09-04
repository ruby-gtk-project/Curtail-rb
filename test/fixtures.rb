# frozen_string_literal: true

# Four real images, one per format Curtail handles, written with the same
# tools the app drives — so the test needs no binary blobs checked in.
module Fixtures
  SVG = <<~SVG
    <?xml version="1.0" encoding="UTF-8"?>
    <!-- a comment scour can strip -->
    <svg xmlns="http://www.w3.org/2000/svg" width="240" height="240">
      <rect x="0" y="0" width="240" height="240" fill="#3584e4"/>
      <circle cx="120" cy="120" r="80" fill="#f6d32d"/>
      <circle cx="90" cy="100" r="14" fill="#241f31"/>
      <circle cx="150" cy="100" r="14" fill="#241f31"/>
    </svg>
  SVG

  module_function

  def build(dir)
    File.write(File.join(dir, 'shape.svg'), SVG)

    png = File.join(dir, 'shape.png')
    noisy_png(png)

    jpg = File.join(dir, 'shape.jpg')
    convert(png, jpg)

    webp = File.join(dir, 'shape.webp')
    system(
      'cwebp',
      '-quiet',
      png,
      '-o',
      webp,
    ) || raise('cwebp failed')

    [png, jpg, webp, File.join(dir, 'shape.svg')]
  end

  # A gradient plus scattered blobs. Flat colour compresses to nothing and
  # every compressor would report "skipped", which tests less than it looks.
  def noisy_png(path)
    require 'cairo'

    Cairo::ImageSurface.new(:rgb24, 256, 256).tap do |surface|
      Cairo::Context.new(surface).tap { |context| paint(context) }
      surface.write_to_png(path)
    end
  end

  def paint(context)
    context.rectangle(
      0,
      0,
      256,
      256,
    )
    context.set_source(gradient)
    context.fill

    Random.new(42).then do |rng|
      300.times do
        context.set_source_rgb(rng.rand, rng.rand, rng.rand)
        context.arc(
          rng.rand(256),
          rng.rand(256),
          rng.rand(3..9),
          0,
          2 * Math::PI,
        )
        context.fill
      end
    end
  end

  def gradient
    Cairo::LinearPattern.new(
      0,
      0,
      256,
      256,
    ).tap do |pattern|
      pattern.add_color_stop_rgb(
        0,
        0.2,
        0.5,
        0.9,
      )
      pattern.add_color_stop_rgb(
        1,
        0.96,
        0.83,
        0.18,
      )
    end
  end

  def convert(png, jpg)
    require 'gdk_pixbuf2'

    GdkPixbuf::Pixbuf.new(file: png).save(jpg, 'jpeg')
  end
end
