# nixosModules/features/plymouth-butterfly/default.nix
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.myNixOS.plymouth-butterfly;

  # Extract Stylix colors for our butterflies
  colors = config.stylix.base16Scheme;

  # Create butterfly theme based on hostname
  butterflyTheme = if (config.networking.hostName == "mariposa") then "mariposa-flight" 
                  else if (config.networking.hostName == "petalouda") then "petalouda-flight"
                  else "default-butterfly";

  # Mariposa (Monarch) SVG with Gruvbox colors
  mariposaButterfly = pkgs.writeText "mariposa-butterfly.svg" ''
    <svg width="120" height="80" viewBox="0 0 120 80" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <radialGradient id="wingGradient" cx="50%" cy="50%" r="50%">
          <stop offset="0%" style="stop-color:#${colors.base09};stop-opacity:1" />
          <stop offset="70%" style="stop-color:#${colors.base08};stop-opacity:0.8" />
          <stop offset="100%" style="stop-color:#${colors.base0F};stop-opacity:0.6" />
        </radialGradient>
        <filter id="glow">
          <feGaussianBlur stdDeviation="2" result="coloredBlur"/>
          <feMerge> 
            <feMergeNode in="coloredBlur"/>
            <feMergeNode in="SourceGraphic"/>
          </feMerge>
        </filter>
      </defs>

      <!-- Upper wings -->
      <ellipse cx="35" cy="25" rx="25" ry="20" fill="url(#wingGradient)" filter="url(#glow)" transform="rotate(-15 35 25)">
        <animateTransform attributeName="transform" type="rotate" 
                         values="-15 35 25;-10 35 25;-15 35 25" dur="0.8s" repeatCount="indefinite"/>
      </ellipse>
      <ellipse cx="85" cy="25" rx="25" ry="20" fill="url(#wingGradient)" filter="url(#glow)" transform="rotate(15 85 25)">
        <animateTransform attributeName="transform" type="rotate" 
                         values="15 85 25;10 85 25;15 85 25" dur="0.8s" repeatCount="indefinite"/>
      </ellipse>

      <!-- Lower wings -->
      <ellipse cx="40" cy="55" rx="18" ry="15" fill="url(#wingGradient)" filter="url(#glow)" transform="rotate(-25 40 55)">
        <animateTransform attributeName="transform" type="rotate" 
                         values="-25 40 55;-20 40 55;-25 40 55" dur="0.8s" repeatCount="indefinite"/>
      </ellipse>
      <ellipse cx="80" cy="55" rx="18" ry="15" fill="url(#wingGradient)" filter="url(#glow)" transform="rotate(25 80 55)">
        <animateTransform attributeName="transform" type="rotate" 
                         values="25 80 55;20 80 55;25 80 55" dur="0.8s" repeatCount="indefinite"/>
      </ellipse>

      <!-- Body -->
      <ellipse cx="60" cy="40" rx="3" ry="25" fill="#${colors.base01}" />

      <!-- Wing patterns -->
      <circle cx="35" cy="25" r="8" fill="#${colors.base0A}" opacity="0.7"/>
      <circle cx="85" cy="25" r="8" fill="#${colors.base0A}" opacity="0.7"/>
      <circle cx="40" cy="55" r="5" fill="#${colors.base08}" opacity="0.8"/>
      <circle cx="80" cy="55" r="5" fill="#${colors.base08}" opacity="0.8"/>
    </svg>
  '';

  # Petalouda (Mediterranean) SVG with blue/purple theme
  petaloudaButterfly = pkgs.writeText "petalouda-butterfly.svg" ''
    <svg width="100" height="70" viewBox="0 0 100 70" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <radialGradient id="wingGradientBlue" cx="50%" cy="50%" r="50%">
          <stop offset="0%" style="stop-color:#${colors.base0D};stop-opacity:1" />
          <stop offset="70%" style="stop-color:#${colors.base0E};stop-opacity:0.8" />
          <stop offset="100%" style="stop-color:#${colors.base0C};stop-opacity:0.6" />
        </radialGradient>
        <filter id="shimmer">
          <feGaussianBlur stdDeviation="1.5" result="coloredBlur"/>
          <feMerge> 
            <feMergeNode in="coloredBlur"/>
            <feMergeNode in="SourceGraphic"/>
          </feMerge>
        </filter>
      </defs>

      <!-- Upper wings -->
      <path d="M30,20 Q15,10 25,35 Q35,25 30,20" fill="url(#wingGradientBlue)" filter="url(#shimmer)">
        <animateTransform attributeName="transform" type="rotate" 
                         values="0 30 25;-5 30 25;0 30 25" dur="1.2s" repeatCount="indefinite"/>
      </path>
      <path d="M70,20 Q85,10 75,35 Q65,25 70,20" fill="url(#wingGradientBlue)" filter="url(#shimmer)">
        <animateTransform attributeName="transform" type="rotate" 
                         values="0 70 25;5 70 25;0 70 25" dur="1.2s" repeatCount="indefinite"/>
      </path>

      <!-- Lower wings -->
      <path d="M35,45 Q20,40 30,60 Q40,50 35,45" fill="url(#wingGradientBlue)" filter="url(#shimmer)">
        <animateTransform attributeName="transform" type="rotate" 
                         values="0 35 50;-3 35 50;0 35 50" dur="1.2s" repeatCount="indefinite"/>
      </path>
      <path d="M65,45 Q80,40 70,60 Q60,50 65,45" fill="url(#wingGradientBlue)" filter="url(#shimmer)">
        <animateTransform attributeName="transform" type="rotate" 
                         values="0 65 50;3 65 50;0 65 50" dur="1.2s" repeatCount="indefinite"/>
      </path>

      <!-- Body -->
      <ellipse cx="50" cy="35" rx="2" ry="20" fill="#${colors.base01}" />

      <!-- Delicate patterns -->
      <circle cx="30" cy="25" r="4" fill="#${colors.base06}" opacity="0.6"/>
      <circle cx="70" cy="25" r="4" fill="#${colors.base06}" opacity="0.6"/>
    </svg>
  '';

in {
  config = mkIf cfg.enable {
    # Install Plymouth with our custom theme
    boot.plymouth = {
      enable = true;
      theme = butterflyTheme;
      themePackages = [
        (pkgs.stdenv.mkDerivation {
          name = "plymouth-butterfly-themes";
          src = pkgs.writeTextDir "dummy" "";

          installPhase = ''
            mkdir -p $out/share/plymouth/themes

            # Mariposa theme (ultrawide optimized)
            mkdir -p $out/share/plymouth/themes/mariposa-flight
            cat > $out/share/plymouth/themes/mariposa-flight/mariposa-flight.plymouth << 'EOF'
            [Plymouth Theme]
            Name=Mariposa Flight
            Description=Animated Monarch butterfly flight across ultrawide display
            ModuleName=script

            [script]
            ImageDir=/share/plymouth/themes/mariposa-flight
            ScriptFile=/share/plymouth/themes/mariposa-flight/mariposa-flight.script
            EOF

            # Mariposa script for ultrawide animation
            cat > $out/share/plymouth/themes/mariposa-flight/mariposa-flight.script << 'EOF'
            # Mariposa (Monarch) Flight Animation for Ultrawide

            # Screen setup
            screen_width = Window.GetWidth();
            screen_height = Window.GetHeight();

            # Background with Gruvbox dark theme
            Window.SetBackgroundTopColor(0x${colors.base00});
            Window.SetBackgroundBottomColor(0x${colors.base01});

            # Load butterfly image
            butterfly_image = Image("butterfly.png");
            butterfly_sprite = Sprite(butterfly_image);

            # Animation variables
            butterfly_x = -120;  # Start off-screen left
            butterfly_y = screen_height / 2 - 40;
            flight_speed = screen_width / 180;  # Cross screen in ~3 seconds
            wing_flutter = 0;

            # Particle trail
            particles = [];

            fun refresh_callback() {
                # Move butterfly across screen
                butterfly_x += flight_speed;

                # Add gentle vertical bobbing
                wing_flutter += 0.1;
                butterfly_y_offset = Math.Sin(wing_flutter) * 8;

                # Reset when butterfly exits screen
                if (butterfly_x > screen_width + 120) {
                    butterfly_x = -120;
                }

                # Position butterfly
                butterfly_sprite.SetPosition(butterfly_x, butterfly_y + butterfly_y_offset, 1);

                # Create particle trail
                if (butterfly_x > 0 && butterfly_x < screen_width) {
                    # Add golden particles behind butterfly
                    particle_image = Image.Text("✨", 1, 1, 1, 0.6);
                    particle_sprite = Sprite(particle_image);
                    particle_sprite.SetPosition(butterfly_x - 30, butterfly_y + butterfly_y_offset + Math.Random() * 20 - 10, 0);
                    particles[particles.size] = particle_sprite;
                }

                # Fade out old particles
                for (i = 0; i < particles.size; i++) {
                    particles[i].SetOpacity(particles[i].GetOpacity() - 0.02);
                    if (particles[i].GetOpacity() <= 0) {
                        particles[i] = NULL;
                    }
                }
            }

            Plymouth.SetRefreshFunction(refresh_callback);

            # Progress bar (subtle)
            progress_box.image = Image("progress_box.png");
            progress_box.sprite = Sprite(progress_box.image);
            progress_box.sprite.SetPosition(screen_width/2 - 100, screen_height - 50, 2);

            fun progress_callback(duration, progress) {
                if (progress_box.image.GetWidth() > 0) {
                    progress_box.sprite.SetOpacity(0.3);
                }
            }

            Plymouth.SetBootProgressFunction(progress_callback);
            EOF

            # Create butterfly PNG from SVG
            ${pkgs.librsvg}/bin/rsvg-convert ${mariposaButterfly} -o $out/share/plymouth/themes/mariposa-flight/butterfly.png -w 120 -h 80

            # Create simple progress box
            ${pkgs.imagemagick}/bin/convert -size 200x4 xc:"#${colors.base04}" $out/share/plymouth/themes/mariposa-flight/progress_box.png

            # Petalouda theme (laptop optimized)
            mkdir -p $out/share/plymouth/themes/petalouda-flight
            cat > $out/share/plymouth/themes/petalouda-flight/petalouda-flight.plymouth << 'EOF'
            [Plymouth Theme]
            Name=Petalouda Flight
            Description=Animated Mediterranean butterfly circular flight
            ModuleName=script

            [script]
            ImageDir=/share/plymouth/themes/petalouda-flight
            ScriptFile=/share/plymouth/themes/petalouda-flight/petalouda-flight.script
            EOF

            # Petalouda script for circular animation
            cat > $out/share/plymouth/themes/petalouda-flight/petalouda-flight.script << 'EOF'
            # Petalouda (Mediterranean) Circular Flight Animation

            # Screen setup
            screen_width = Window.GetWidth();
            screen_height = Window.GetHeight();
            center_x = screen_width / 2;
            center_y = screen_height / 2;

            # Background with Gruvbox dark theme
            Window.SetBackgroundTopColor(0x${colors.base00});
            Window.SetBackgroundBottomColor(0x${colors.base01});

            # Load butterfly image
            butterfly_image = Image("butterfly.png");
            butterfly_sprite = Sprite(butterfly_image);

            # Animation variables
            angle = 0;
            radius = Math.Min(screen_width, screen_height) / 4;

            fun refresh_callback() {
                # Circular flight path
                angle += 0.03;
                butterfly_x = center_x + Math.Cos(angle) * radius;
                butterfly_y = center_y + Math.Sin(angle) * radius * 0.6;  # Elliptical

                # Rotate butterfly to face direction of travel
                butterfly_sprite.SetPosition(butterfly_x - 50, butterfly_y - 35, 1);

                # Create sparkle trail
                if (Math.Random() > 0.7) {
                    sparkle_image = Image.Text("✦", 0.49, 0.68, 0.64, 0.8);  # base0D color
                    sparkle_sprite = Sprite(sparkle_image);
                    sparkle_sprite.SetPosition(butterfly_x + Math.Random() * 40 - 20, butterfly_y + Math.Random() * 40 - 20, 0);
                }
            }

            Plymouth.SetRefreshFunction(refresh_callback);

            # Progress indicator
            fun progress_callback(duration, progress) {
                # Subtle progress ring around flight path
            }

            Plymouth.SetBootProgressFunction(progress_callback);
            EOF

            # Create butterfly PNG from SVG
            ${pkgs.librsvg}/bin/rsvg-convert ${petaloudaButterfly} -o $out/share/plymouth/themes/petalouda-flight/butterfly.png -w 100 -h 70
          '';
        })
      ];
    };

    # Ensure smooth boot experience
    boot.kernelParams = [ 
      "quiet" 
      "splash" 
      "loglevel=3" 
      "rd.systemd.show_status=false" 
      "rd.udev.log_level=3" 
      "udev.log_priority=3" 
    ];

    # Hide cursor during boot
    boot.loader.timeout = 0;
  };
}

