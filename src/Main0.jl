﻿using SimpleDirectMediaLayer.LibSDL2
include("Collider.jl")
include("Constants.jl")
include("Entity.jl")
include("Enums.jl")
include("Input/Input.jl")
include("RenderWindow.jl")
include("Rigidbody.jl")
include("Scene.jl")
include("Sprite.jl")
include("Transform.jl")
include("Utils.jl")
include("Math/Vector2f.jl")

mutable struct MainLoop
    scene::Scene
    
    function MainLoop(scene)
        this = new()
		
		this.scene = scene
		
        return this
    end
end

function Base.getproperty(this::MainLoop, s::Symbol)
    if s == :start 
        function()
			SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 16)
			SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 16)
			
			#initializing
			@assert SDL_Init(SDL_INIT_EVERYTHING) == 0 "error initializing SDL: $(unsafe_string(SDL_GetError()))"
			@assert TTF_Init() == 0 "error initializing SDL: $(unsafe_string(TTF_GetError()))"
			font = TTF_OpenFont(joinpath(@__DIR__, "..","assets/fonts/FiraCode/ttf/FiraCode-Regular.ttf"), 150)

			window = SDL_CreateWindow("Game", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 1000, 1000, SDL_WINDOW_SHOWN)
			SDL_SetWindowResizable(window, SDL_TRUE)
			renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC)
			for sprite in this.scene.sprites
				sprite.injectRenderer(renderer)
			end
			
			windowRefreshRate = 60
			colliders = this.scene.colliders
			sprites = this.scene.sprites
			rigidbodies = this.scene.rigidbodies
			entities = this.scene.entities
			input = Input()

			w_ref, h_ref = Ref{Cint}(0), Ref{Cint}(0)
            try
				w, h = w_ref[], h_ref[]
				x::Float64 = entities[1].getTransform().getPosition().x
				y = entities[1].getTransform().getPosition().y
				
				DEBUG = false
				close = false
				speed = 200
				gravity = GRAVITY
				timeStep = 0.01
				startTime = 0.0
				totalFrames = 0
				grounded = false
				wasGrounded = false
				isFacingRight = true
				flipPlayer = false 
			
				#animation vars
				animatedFPS = 12.0
				
				#physics vars
				lastPhysicsTime = SDL_GetTicks()
				
				while !close
					# Start frame timing
					totalFrames += 1
					lastStartTime = startTime
					startTime = SDL_GetPerformanceCounter()
					#region ============= Input
					input.pollInput()
					if input.quit
						close = true
					end
					
					scan_code = input.scan_code
			
					if scan_code == SDL_SCANCODE_W || scan_code == SDL_SCANCODE_UP
						y -= speed / 30
					elseif scan_code == SDL_SCANCODE_A || scan_code == SDL_SCANCODE_LEFT
						x = -speed
						if isFacingRight
							isFacingRight = false
							flipPlayer = true
						end
					elseif scan_code == SDL_SCANCODE_S || scan_code == SDL_SCANCODE_DOWN
						y += speed / 30
					elseif scan_code == SDL_SCANCODE_D || scan_code == SDL_SCANCODE_RIGHT
						x = speed
						if !isFacingRight
							isFacingRight = true
							flipPlayer = true
						end
					elseif gravity == GRAVITY && scan_code == SDL_SCANCODE_SPACE
						println("space")
						gravity = -GRAVITY
					elseif scan_code == SDL_SCANCODE_F3 
						println("debug toggled")
						DEBUG = !DEBUG
					else
						#nothing
					end
			
					keyup = input.keyup
					if keyup == SDL_SCANCODE_W || keyup == SDL_SCANCODE_UP
						#y -= speed / 30
					elseif x == -speed && (keyup == SDL_SCANCODE_A || keyup == SDL_SCANCODE_LEFT)            
						x = 0
					elseif keyup == SDL_SCANCODE_S || keyup == SDL_SCANCODE_DOWN
						# y += speed / 30
					elseif x == speed && (keyup == SDL_SCANCODE_D || keyup == SDL_SCANCODE_RIGHT)
						x = 0
					elseif keyup == SDL_SCANCODE_SPACE
						gravity = GRAVITY
					end
			
					input.scan_code = nothing
					input.keyup = nothing
				   
					#endregion ============== Input
						
					#Physics
					currentPhysicsTime = SDL_GetTicks()
					
					
					#println(gravity)
					if grounded && !wasGrounded
						rigidbodies[1].setVelocity(Vector2f(rigidbodies[1].getVelocity().x, 0))
						#println("landed")
					elseif grounded && gravity == -GRAVITY
						rigidbodies[1].setVelocity(Vector2f(rigidbodies[1].getVelocity().x, gravity))
					elseif !grounded
						rigidbodies[1].setVelocity(Vector2f(rigidbodies[1].getVelocity().x, gravity == GRAVITY ? gravity : rigidbodies[1].getVelocity().y))
					end
					
					wasGrounded = grounded
					
					deltaTime = (currentPhysicsTime - lastPhysicsTime) / 1000.0
					#println(deltaTime)
					rigidbodies[1].setVelocity(Vector2f(x, rigidbodies[1].getVelocity().y))
					
					for rigidbody in rigidbodies
						transform = rigidbody.getParent().getTransform()
						transform.setPosition(Vector2f(transform.getPosition().x  + rigidbody.velocity.x / SCALE_UNITS * deltaTime, transform.getPosition().y  + rigidbody.velocity.y / SCALE_UNITS * deltaTime))
					end
					
					grounded = false
					counter = 1
			
					#Only check the player against other colliders
					for colliderB in colliders
					#TODO: Skip any out of a certain range of the player. This will prevent a bunch of unnecessary collision checks
						if colliders[1] != colliderB
							collision = checkCollision(colliders[1], colliderB)
							transform = colliders[1].getParent().getTransform()
							if collision[1] == Top::CollisionDirection
								#Begin to overlap, correct position
								transform.setPosition(Vector2f(transform.getPosition().x, transform.getPosition().y + collision[2]))
							elseif collision[1] == Left::CollisionDirection
								#Begin to overlap, correct position
								transform.setPosition(Vector2f(transform.getPosition().x + collision[2], transform.getPosition().y))
								#If player tries to move left here, stop them
								#x < 0 && (x = 0;) 
							elseif collision[1] == Right::CollisionDirection
								#Begin to overlap, correct position
								transform.setPosition(Vector2f(transform.getPosition().x - collision[2], transform.getPosition().y))
								#If player tries to move right here, stop them
								#x > 0 && (x = 0;) 
							elseif collision[1] == Bottom::CollisionDirection
								#Begin to overlap, correct position
								#println("grounded")
								grounded = true
								transform.setPosition(Vector2f(transform.getPosition().x, transform.getPosition().y - collision[2]))
								break
							elseif collision[1] == Below::ColliderLocation
								#Remain on top. Resting on collider
								#println("hit")
								grounded = true
							elseif !grounded && counter == length(colliders) && collision[1] != Bottom::CollisionDirection # If we're on the last collider to check and we haven't collided with anything yet
								#println("not grounded")
								grounded = false
							end
						end
						counter += 1
					end    
			
					lastPhysicsTime =  SDL_GetTicks()
					#Rendering
					currentRenderTime = SDL_GetTicks()
					SDL_SetRenderDrawColor(renderer, 0, 0, 0, SDL_ALPHA_OPAQUE);
					SDL_RenderClear(renderer)
        			#window.clear()
			
					SDL_SetRenderDrawColor(renderer, 0, 255, 0, SDL_ALPHA_OPAQUE)
			
					for entity in entities
						entity.update()
						if DEBUG && entity.getCollider() != C_NULL
							pos = entity.getTransform().getPosition()
							colSize = entity.getCollider().getSize()
							SDL_RenderDrawLines(renderer, [
								SDL_Point(round(pos.x * SCALE_UNITS), round(pos.y * SCALE_UNITS)), 
								SDL_Point(round(pos.x * SCALE_UNITS + colSize.x * SCALE_UNITS), round(pos.y * SCALE_UNITS)),
								SDL_Point(round(pos.x * SCALE_UNITS + colSize.x * SCALE_UNITS), round(pos.y * SCALE_UNITS + colSize.y * SCALE_UNITS)), 
								SDL_Point(round(pos.x * SCALE_UNITS), round(pos.y * SCALE_UNITS  + colSize.y * SCALE_UNITS)), 
								SDL_Point(round(pos.x * SCALE_UNITS), round(pos.y * SCALE_UNITS))], 5)
						end
					end
			
					if flipPlayer
						sprites[1].flip()
						flipPlayer = false
					end
					for sprite in sprites
						deltaTime = (currentRenderTime  - sprite.getLastUpdate()) / 1000.0
						framesToUpdate = floor(deltaTime / (1.0 / animatedFPS))
						if framesToUpdate > 0
							sprite.setLastFrame(sprite.getLastFrame() + framesToUpdate)
							sprite.setLastFrame(sprite.getLastFrame() % sprite.getFrameCount())
							sprite.setLastUpdate(currentRenderTime)
						end
						sprite.draw(Ref(SDL_Rect(sprite.getLastFrame() * 16,0,16,16)))
					end
					
					if DEBUG
						# Strings to display
						text = TTF_RenderText_Blended( font, string("FPS: ", round(1000 / round((startTime - lastStartTime) / SDL_GetPerformanceFrequency() * 1000.0))), SDL_Color(0,255,0,255) )
						text1 = TTF_RenderText_Blended( font, string("Frame time: ", round((startTime - lastStartTime) / SDL_GetPerformanceFrequency() * 1000.0), "ms"), SDL_Color(0,255,0,255) )
						textTexture = SDL_CreateTextureFromSurface(renderer,text)
						textTexture1 = SDL_CreateTextureFromSurface(renderer,text1)
						SDL_RenderCopy(renderer, textTexture, C_NULL, Ref(SDL_Rect(0,0,150,50)))
						SDL_RenderCopy(renderer, textTexture1, C_NULL, Ref(SDL_Rect(0,50,200,50)))
					end
			
					SDL_RenderPresent(renderer)
					endTime = SDL_GetPerformanceCounter()
					elapsedMS = (endTime - startTime) / SDL_GetPerformanceFrequency() * 1000.0
					targetFrameTime = 1000/windowRefreshRate
			
					if elapsedMS < targetFrameTime
    					SDL_Delay(round(targetFrameTime - elapsedMS))
					end
				end
			finally
				TTF_CloseFont( font );
				TTF_Quit()
				SDL_DestroyRenderer(renderer)
				SDL_DestroyWindow(window)
				SDL_Quit()
			end
        end
    else
        getfield(this, s)
    end
end


