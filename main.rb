require 'ruby2d'

# Define a method to close the game window
def close_game
  Ruby2D::Window.close
end

# Player class represents the player character
class Player
  attr_accessor :x, :y, :angle, :lives, :death_time, :death_image, :death_sound

  def initialize
    # Initial player position and attributes
    @x = 300
    @y = 300
    @target_x = @x
    @target_y = @y
    @angle = 0
    @lives = 3  # Player starts with 3 lives
    @death_time = nil
    @death_image = nil
    @death_sound = Sound.new('you_died_sound.mp3')

    # Load and configure the player sprite
    @shooter = Sprite.new(
      'img/shooter_move_sprite.png',
      clip_width: 312,
      time: 300,
      width: 55,
      height: 50,
      x: @x, y: @y,
      rotate: @angle,
      loop: false
    )
  end

  # Move player towards the target position
  def move_to_target
    direction_x = @target_x - @x
    direction_y = @target_y - @y
    magnitude = Math.sqrt(direction_x ** 2 + direction_y ** 2)
    normalized_x = direction_x / magnitude
    normalized_y = direction_y / magnitude

    @x += normalized_x
    @y += normalized_y

    # Update the position and rotation of the sprite
    @shooter.x = @x
    @shooter.y = @y
    @angle = Math.atan2(normalized_y, normalized_x) * 180 / Math::PI
    @shooter.rotate = @angle
  end

  # Set the player's target position
  def set_target(target_x, target_y)
    @target_x = target_x
    @target_y = target_y
    @shooter.play
  end

  # Handle player taking damage
  def take_damage
    @lives -= 1
    if @lives <= 0 && !@death_time
      @death_sound.play
      @death_image = Image.new(
        'you_died_1.jpg',
        width: 1600, height: 757,
        x: 0, y: 0
      )
      @death_time = Time.now + 7  # Show death screen for 7 seconds
    end
  end

  # Update player status, such as removing the death image
  def update
    if @death_image && Time.now > @death_time
      @death_image.remove
      close_game
    end
  end
end

# Bullet class represents a bullet fired by the player
class Bullet
  attr_accessor :circle, :velocity_x, :velocity_y, :active

  def initialize(start_x, start_y, target_x, target_y, speed)
    # Initialize bullet's position and appearance
    @circle = Circle.new(
      x: start_x, y: start_y,
      radius: 4,
      sectors: 32,
      color: 'black',
      z: 0
    )

    @velocity_x = 0
    @velocity_y = 0
    @speed = speed
    @active = true

    # Calculate velocity components based on direction to the target
    diff_x = target_x - start_x
    diff_y = target_y - start_y
    distance = Math.sqrt(diff_x**2 + diff_y**2)
    @velocity_x = (diff_x / distance) * @speed
    @velocity_y = (diff_y / distance) * @speed
  end

  # Update bullet's position based on its velocity
  def update
    @circle.x += @velocity_x
    @circle.y += @velocity_y
  end
end

# Zombie class represents a zombie enemy
class Zombie
  attr_accessor :x, :y, :target_x, :target_y, :speed, :zombie_sprite, :dead, :last_damage_time

  def initialize(x, y, player)
    # Initialize zombie's position and attributes
    @x = x
    @y = y
    @target_x = player.x
    @target_y = player.y
    @speed = 0.5
    @lives = 1
    @dead = false
    @last_damage_time = Time.now

    # Load and configure the zombie sprite
    @zombie_sprite = Sprite.new(
      'img/zombie-walk-sprite.png',
      clip_width: 290,
      time: 250,
      width: 50,
      height: 50,
      x: @x, y: @y,
      loop: true
    )
    @zombie_sprite.play
  end

  # Update zombie's position and behavior
  def update(player)
    # Update target position to player's current position
    @target_x = player.x
    @target_y = player.y

    # Calculate direction towards the player
    direction_x = @target_x - @x
    direction_y = @target_y - @y
    magnitude = Math.sqrt(direction_x ** 2 + direction_y ** 2)
    if magnitude > 10
      normalized_x = direction_x / magnitude
      normalized_y = direction_y / magnitude
      @x += normalized_x * @speed
      @y += normalized_y * @speed
      @zombie_sprite.x = @x
      @zombie_sprite.y = @y
      @zombie_sprite.rotate = Math.atan2(normalized_y, normalized_x) * 180 / Math::PI
    end

    # Apply damage to the player every second if close enough
    if Time.now - @last_damage_time >= 1
      if player_hit?(player)
        player.take_damage
        @last_damage_time = Time.now
      end
    end
  end

  # Handle zombie being hit by a bullet
  def hit_by_bullet
    @lives -= 1
    if @lives <= 0
      @zombie_sprite.remove
      @dead = true
    end
  end

  # Check if the zombie is close enough to hit the player
  def player_hit?(player)
    distance = Math.sqrt((player.x - @x)**2 + (player.y - @y)**2)
    distance < 30
  end
end

# Initialize the game window and set background
set title: "Top Down Shooter", width: 1600, height: 757
set background: Image.new("img/shooter_map.png", width: 1600, height: 757)

# Initialize player, bullets, and zombies
player = Player.new
bullets = []
zombies = []

# Initialize shooting sound and shooting flag
shooting_sound = Sound.new('gunshot.mp3')
shooting = false

# Initialize last shot time
last_shot_time = Time.now

# Round-based spawning system
round = 1
zombies_per_round = 10
total_zombies = 0

# Event handlers for mouse input
on :mouse_down do |event|
  shooting = true
end

on :mouse_up do |event|
  shooting = false
  shooting_sound.play
end

# Text to display number of zombies left
zombies_left_text = Text.new(
  "Zombies Left: #{total_zombies}",
  x: 720, y: 40,
  size: 20,
  color: 'white'
)

# Text to display player's remaining lives
player_lives_text = Text.new(
  "Lives: #{player.lives}",
  x: 720, y: 70,
  size: 20,
  color: 'white'
)

# Main game update loop
update do
  # Set player's target position based on the mouse cursor
  player.set_target(get(:mouse_x), get(:mouse_y))
  player.move_to_target

  # Update player's remaining lives display
  player_lives_text.text = "Lives: #{player.lives}"

  # Check if all zombies in the current round are dead and spawn new ones if needed
  if zombies.empty? && !shooting
    round += 1
    total_zombies += zombies_per_round * round - 10
    (1..total_zombies).each do
      x1 = rand(1600)
      y1 = rand(30)
      y2 = rand(717..757)
      if rand(1..2) == 1
        zombies << Zombie.new(x1, y1, player)
      else
        zombies << Zombie.new(x1, y2, player)
      end
    end
  end

  # Handle bullet firing
  if shooting
    current_time = Time.now
    if current_time - last_shot_time >= 0.30
      bullets << Bullet.new(player.x, player.y, get(:mouse_x), get(:mouse_y), 10)
      last_shot_time = current_time
      shooting_sound.play
    end
  end

  # Update zombies and check for player damage
  zombies.each { |zombie| zombie.update(player) }

  # Update bullets and check for collisions with zombies
  bullets.each do |bullet|
    bullet.update
    zombies.each do |zombie|
      distance = Math.sqrt((bullet.circle.x - zombie.x)**2 + (bullet.circle.y - zombie.y)**2)
      if distance < 35
        zombie.hit_by_bullet
        bullet.active = false
        bullet.circle.remove
        total_zombies -= 1
        break
      end
    end
  end

  # Remove inactive bullets
  bullets.reject! { |bullet| !bullet.active }

  # Remove dead zombies
  zombies.reject!(&:dead)

  # Update zombies remaining display
  zombies_left_text.text = "Zombies Left: #{total_zombies}"

  # Update player status (e.g., check for death)
  player.update
end

# Show the game window
show
