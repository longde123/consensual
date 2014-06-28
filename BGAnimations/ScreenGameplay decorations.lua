local rate_coordinator= setmetatable({}, rate_coordinator_interface_mt)
rate_coordinator:initialize()

-- The order of these elements also affects the coloring of the score meter.
local feedback_judgements= {
	"TapNoteScore_Miss", "TapNoteScore_W5", "TapNoteScore_W4",
	"TapNoteScore_W3", "TapNoteScore_W2", "TapNoteScore_W1"
}

local screen_gameplay= false

local receptor_min= THEME:GetMetric("Player", "ReceptorArrowsYStandard")
local receptor_max= THEME:GetMetric("Player", "ReceptorArrowsYReverse")
local arrow_height= THEME:GetMetric("ArrowEffects", "ArrowSpacing")
local field_height= receptor_max - receptor_min

local line_spacing= 24
local h_line_spacing= line_spacing / 2

local judge_spacing= line_spacing
local judge_y= SCREEN_BOTTOM - (judge_spacing * (#feedback_judgements + 3))
local judge_centers= {
	[PLAYER_1]= { SCREEN_CENTER_X - (SCREEN_CENTER_X / 2), judge_y},
	[PLAYER_2]= { SCREEN_CENTER_X + (SCREEN_CENTER_X / 2), judge_y}
}

local player_sides= {
	[PLAYER_1]=
		THEME:GetMetric("ScreenGameplay", "PlayerP1OnePlayerOneSideX"),
	[PLAYER_2]=
		THEME:GetMetric("ScreenGameplay", "PlayerP2OnePlayerOneSideX")}
local side_diffs= {
	[PLAYER_1]= player_sides[PLAYER_2] - player_sides[PLAYER_1],
	[PLAYER_2]= player_sides[PLAYER_1] - player_sides[PLAYER_2]}
local side_swap_vals= {}
local swap_on_xs= {}
local side_toggles= {}
local side_actors= {}

local judge_feedback_interface= {}
function judge_feedback_interface:create_actors(name, fx, fy, player_number)
	if not name then return nil end
	self.name= name
	self.player_number= player_number
	if not fx then fx= 0 end
	if not fy then fy= 0 end
	self.elements= {}
	local args= { Name= name, InitCommand= cmd(x,fx;y,fy) }
	local tx= -10
	local nx= 10
	local start_y= 0
	for n= 1, #feedback_judgements do
		local new_element= {}
		setmetatable(new_element, text_and_number_interface_mt)
		args[#args+1]= new_element:create_actors(
			feedback_judgements[n], {
				sy= start_y + judge_spacing * n, tx= tx, nx= nx,
				tc= judgement_colors[feedback_judgements[n]],
				nc= judgement_colors[feedback_judgements[n]],
				text_section= "JudgementNames",
				tt= feedback_judgements[n]})
		self.elements[#self.elements+1]= new_element
	end
	return Def.ActorFrame(args)
end

function judge_feedback_interface:find_actors(container)
	if not container then return nil end
	self.container= container
	for n= 1, #self.elements do
		local ele= self.elements[n]
		local ele_con= container:GetChild(ele.name)
		if not ele:find_actors(ele_con) then
			Trace("Judge feedback element " .. n .. " " .. ele.name .. " could not find its actors.")
		end
	end
	return true
end

function judge_feedback_interface:update(player_stage_stats)
	if cons_players[self.player_number].fake_judge then
		local fake_score= cons_players[self.player_number].fake_score
		for n= 1, #self.elements do
			local ele= self.elements[n]
			ele:set_number(fake_score.judge_counts[ele.name])
		end
	else
		for n= 1, #self.elements do
			local ele= self.elements[n]
			ele:set_number(player_stage_stats:GetTapNoteScores(ele.name))
		end
	end
end

local judge_feedback_interface_mt= { __index= judge_feedback_interface }

local sigil_centers= {
	[PLAYER_1]= { SCREEN_CENTER_X - (SCREEN_CENTER_X / 2), SCREEN_BOTTOM*.375},
	[PLAYER_2]= { SCREEN_CENTER_X + (SCREEN_CENTER_X / 2), SCREEN_BOTTOM*.375}
}
local prev_sigil_states= {}

dofile(THEME:GetPathO("", "sigil.lua"))

local sigil_feedback_interface= {}
function sigil_feedback_interface:create_actors(name, fx, fy, player_number)
	if not name then return nil end
	self.name= name
	self.player_number= player_number
	local player_data= cons_players[player_number].sigil_data
	-- Initial data should ensure that all actors get updated the first frame.
	self.prev_state= { detail= player_data.detail, fill_amount= 1}
	if not fx then fx= 0 end
	if not fy then fy= 0 end
	self.sigil= setmetatable({}, sigil_controller_mt)
	return self.sigil:create_actors(name, fx, fy, solar_colors[player_number](), player_data.detail, player_data.size)
end

function sigil_feedback_interface:find_actors(container)
	if not container then return nil end
	self.container= container
	self.sigil:find_actors(container)
	self.actor_set= {}
	self.sigil:redetail(self.prev_state.detail)
	return true
end

function sigil_feedback_interface:update(player_stage_stats)
	local pstats= player_stage_stats
	local life= pstats:GetCurrentLife()
	local adp= pstats:GetActualDancePoints()
	if cons_players[self.player_number].fake_judge then
		adp= cons_players[self.player_number].fake_score.dp
	end
	local pdp= pstats:GetCurrentPossibleDancePoints()
	local score= adp / pdp
	if pdp == 0 then
		score= 1
	end
	--Trace("SGBG.Update:  Current life:  " .. life .. "\n  ADP:  " .. adp ..
	--   "\n  pdp:  " .. pdp .. "\n  score:  " .. score)
	local new_detail= math.max(1, math.round(self.sigil.max_detail * ((score - .5) * 2)))
	self.sigil:redetail(new_detail)
	self.prev_state.detail= new_detail
	self.prev_state.fill_amount= life
end

function sigil_feedback_interface:draw_sigil(detail)
	draw_sigil_with_actors(detail, self.actor_set, sigil_line_len, 0, 0)
end

local sigil_feedback_interface_mt= { __index= sigil_feedback_interface }

local score_feedback_interface= {}
local score_feedback_centers= {
	[PLAYER_1]= { SCREEN_LEFT + 32, SCREEN_BOTTOM },
	[PLAYER_2]= { SCREEN_RIGHT - 32, SCREEN_BOTTOM }
}
function score_feedback_interface:create_actors(name, fx, fy, player_number)
	if not name then return nil end
	self.name= name
	self.player_number= player_number
	if not fx then fx= 0 end
	if not fy then fy= 0 end
	return Def.ActorFrame{
		Name= name, InitCommand= cmd(x,fx;y,fy),
		Def.Quad{ Name= "meter",
							InitCommand= function(self)
														 self:SetWidth(16)
														 self:SetHeight(SCREEN_BOTTOM)
														 self:vertalign(bottom)
													 end
						}
	}
end

function score_feedback_interface:find_actors(container)
	if not container then return nil end
	self.container= container
	self.meter= container:GetChild("meter")
	if not self.meter then return nil end
	return true
end

function score_feedback_interface:update(player_stage_stats)
	local adp= player_stage_stats:GetActualDancePoints()
	local mdp= player_stage_stats:GetPossibleDancePoints()
	local fake_score
	if cons_players[self.player_number].fake_judge then
		fake_score= cons_players[self.player_number].fake_score
		adp= fake_score.dp
	end
	local score= adp / mdp
	local function set_color(c)
		self.meter:diffuse(c)
	end
	if fake_score then
		for i, fj in ipairs(feedback_judgements) do
			if fake_score.judge_counts[fj] > 0 then
				set_color(judgement_colors[fj])
				break
			end
		end
	else
		for i, fj in ipairs(feedback_judgements) do
			if player_stage_stats:GetTapNoteScores(fj) > 0 then
				set_color(judgement_colors[fj])
				break
			end
		end
	end
	self.meter:zoomy(score^((score+1)^((score*2.718281828459045))))
end

local score_feedback_interface_mt= { __index= score_feedback_interface }

local dance_points_feedback_interface= {}
local dp_feedback_centers= {
	[PLAYER_1]= { SCREEN_RIGHT * .25, SCREEN_TOP + h_line_spacing },
	[PLAYER_2]= { SCREEN_RIGHT * .75, SCREEN_TOP + h_line_spacing }
}
function dance_points_feedback_interface:create_actors(name, fx, fy, player_number)
	if not name then return nil end
	self.name= name
	self.player_number= player_number
	if not fx then fx= 0 end
	if not fy then fy= 0 end
	return Def.ActorFrame{
		Name= name, InitCommand= cmd(x,fx;y,fy),
		normal_text("curr_dp", "0", solar_colors.f_text(), -10, 0, 1, right),
		normal_text("slash", "/", solar_colors.f_text(), 0, 0, 1),
		normal_text("max_dp", "0", solar_colors.f_text(), 10, 0, 1, left),
	}
end

function dance_points_feedback_interface:find_actors(container)
	if not container then return nil end
	self.container= container
	self.curr_text= container:GetChild("curr_dp")
	self.max_text= container:GetChild("max_dp")
	return true
end

function dance_points_feedback_interface:update(player_stage_stats)
	local adp= player_stage_stats:GetActualDancePoints()
	local mdp= player_stage_stats:GetPossibleDancePoints()
	local fake_score
	if cons_players[self.player_number].fake_judge then
		fake_score= cons_players[self.player_number].fake_score
		adp= fake_score.dp
	end
	local function set_color(c)
		self.curr_text:diffuse(c)
		self.max_text:diffuse(c)
	end
	if fake_score then
		for i, fj in ipairs(feedback_judgements) do
			if fake_score.judge_counts[fj] > 0 then
					set_color(judgement_colors[fj])
					break
				end
		end
	else
		for i, fj in ipairs(feedback_judgements) do
			if player_stage_stats:GetTapNoteScores(fj) > 0 then
				set_color(judgement_colors[fj])
				break
			end
		end
	end
	self.curr_text:settext(tostring(adp))
	self.max_text:settext(tostring(mdp))
end

local dance_points_feedback_interface_mt= { __index= dance_points_feedback_interface }

local bpm_feedback_interface= {}
local bpm_y= SCREEN_BOTTOM - line_spacing
local bpm_centers= {
	[PLAYER_1]= { SCREEN_CENTER_X - (SCREEN_CENTER_X / 2), bpm_y},
	[PLAYER_2]= { SCREEN_CENTER_X + (SCREEN_CENTER_X / 2), bpm_y}
}
local bpm_feedback_interface_mt= { __index= bpm_feedback_interface }
function bpm_feedback_interface:create_actors(name, fx, fy, player_number)
	self.name= name
	self.tani= setmetatable({}, text_and_number_interface_mt)
	self.player_number= player_number
	return Def.ActorFrame{
		Name= self.name, InitCommand= cmd(xy, fx, fy),
		self.tani:create_actors(
			"tani", { tx= -4, nx= 4, tt= "BPM: ", text_section= "ScreenGameplay"
							})
	}
end

function bpm_feedback_interface:find_actors(container)
	if not container then return nil end
	self.container= container
	self.tani:find_actors(container:GetChild(self.tani.name))
	return true
end

function bpm_feedback_interface:update()
	if self.container then
		local pstate= GAMESTATE:GetPlayerState(self.player_number)
		if pstate and screen_gameplay.GetTrueBPS then
			local bpm= screen_gameplay:GetTrueBPS(self.player_number) * 60
			self.tani:set_number(("%.0f"):format(bpm))
		end
	end
end

local feedback_things= { [PLAYER_1]= {}, [PLAYER_2]= {}}

-- SCREEN_WIDTH - life_bar_width - score_feedback_width
-- spb_width is also used as the width of the title.
local spb_width= SCREEN_WIDTH - 48 - 32
local spb_height= 16
local spb_x= SCREEN_CENTER_X
local spb_y= SCREEN_BOTTOM - (spb_height / 2)

local song_progress_bar_interface= {}
local song_progress_bar_interface_mt= { __index= song_progress_bar_interface }
function song_progress_bar_interface:create_actors()
	self.name= "song_progress"
	return Def.ActorFrame{
		Name= self.name, InitCommand= cmd(xy, spb_x, spb_y),
		create_frame_quads("frame", .5, spb_width, spb_height,
											 solar_colors.f_text(.5), solar_colors.bg(.5), 0, 0),
		Def.Quad{
			Name= "filler", InitCommand=
				function(self)
					self:diffuse(solar_colors.green())
					self:x(spb_width * -.5)
					self:horizalign(left)
					self:SetWidth(spb_width)
					self:SetHeight(spb_height-1)
					self:zoomx(0)
				end
		}
	}
end

function song_progress_bar_interface:find_actors(container)
	if not container then return nil end
	Trace("spbi:fa")
	self.container= container
	self.filler= container:GetChild("filler")
	if not self.filler then Trace("nil filler.") end
	self.song_first_second= 0
	self.song_len= 1
end

function song_progress_bar_interface:set_from_song()
	local song= GAMESTATE:GetCurrentSong()
	if song then
		self.song_first_second= song:GetFirstSecond()
		self.song_len= song:GetLastSecond() - self.song_first_second
	else
		Trace("Current song is nil on ScreenGameplay")
	end
end

do
	local progress_colors= {
		solar_colors.green(.5),
		solar_colors.yellow(.5),
		solar_colors.orange(.5),
		solar_colors.red(.5),
		solar_colors.magenta(.5),
		solar_colors.violet(.5),
		solar_colors.blue(.5),
		solar_colors.cyan(.5)
	}
	function song_progress_bar_interface:update()
		local cur_seconds= GAMESTATE:GetCurMusicSeconds()
		local zoom= (cur_seconds - self.song_first_second) / self.song_len
		self.filler:diffuse(convert_percent_to_color(zoom, .5))
		self.filler:zoomx(zoom)
	end
end
local song_progress_bar= setmetatable({}, song_progress_bar_interface_mt)

local function find_special_actors(self)
	local spec_acts= self:GetChild("special_actors")
	if not spec_acts then return end
	song_progress_bar:find_actors(spec_acts:GetChild(song_progress_bar.name))
	for k, v in pairs(feedback_things) do
		local pcon= spec_acts:GetChild(k)
		if pcon then
			for fk, fv in pairs(v) do
				if not fv:find_actors(pcon:GetChild(fv.name)) then
					Trace("Feedback thing " .. tostring(fv.name) .. " for player " .. tostring(k) ..
						" could not find its actors.")
				end
			end
		end
	end
end

local half_scrw= (SCREEN_WIDTH / 2)
local half_scrh= (SCREEN_HEIGHT / 2)
local to_radians= math.pi / 180
local base_len= math.sqrt((half_scrw * half_scrw) + (half_scrh * half_scrh))
local base_x= -half_scrw
local base_y= -half_scrh
local base_z= 0
local curr_x= base_x
local curr_y= base_y
local curr_z= base_z
local base_angle_x= 0
local base_angle_y= 0
local base_angle_z= 0
base_angle_z= math.atan2(base_y, base_x)

local function reposition_screen(screen)
	local rx= (screen:GetRotationX() * to_radians) + base_angle_x
	local ry= (screen:GetRotationY() * to_radians) + base_angle_y
	local rz= (screen:GetRotationZ() * to_radians) + base_angle_z
	local tx= math.cos(rz)
	local ty= math.sin(rz)
	local nx= math.cos(ry) * tx * base_len
	local tz= math.sin(ry) * tx
	local yz_mag= math.sqrt(ty * ty + tz * tz)
	local ny= math.sin(rx) * yz_mag * base_len
	local nz= math.cos(rx) * yz_mag * base_len
	--   Trace(("Angles: %f.3, %f.3  Pos: %f.3, %f.3, %f.3"):format(try, trz, nx, ny, nz))
	screen:x(nx)
	screen:y(ny)
	screen:z(nz)
end
local function rotate_screen_z(screen, rot)
	-- The screen is rotated around its top left corner, but we want to
	-- rotate around its center.
	--   base_angle_z= math.atan2(curr_y, curr_x)
	--   local total_angle= (rot * to_radians) + base_angle_z
	--   local angle_x= math.cos(total_angle) * base_len
	--   local angle_y= math.sin(total_angle) * base_len
	--   local new_x= half_scrw + (angle_x)
	--   local new_y= half_scrh + (angle_y)
	--   screen:xy(new_x, new_y)
	screen:rotationz(rot)
	reposition_screen(screen)
end

local function rotate_screen_y(screen, rot)
	screen:rotationy(rot)
end

local function rotate_screen_x(screen, rot)
	screen:rotationx(rot)
end

gameplay_start_time= -20
gameplay_end_time= 0
local timer_actor

local function get_screen_time()
	return timer_actor:GetSecsIntoEffect()
end

local dspeed_default_min= 0
local dspeed_default_max= 2
do
	local receptor_min= THEME:GetMetric("Player", "ReceptorArrowsYStandard")
	local receptor_max= THEME:GetMetric("Player", "ReceptorArrowsYReverse")
	local arrow_height= THEME:GetMetric("ArrowEffects", "ArrowSpacing")
	local field_height= receptor_max - receptor_min
	local center_effect_size= field_height / 2
	dspeed_default_min= (SCREEN_CENTER_Y + receptor_min) / -center_effect_size
	dspeed_default_max= (SCREEN_CENTER_Y + receptor_max) / center_effect_size
end
local dspeed_default_range= dspeed_default_max - dspeed_default_min

local suddmin= -1
local suddmax= .5

local function dspeed_start(player)
	local pdspeed= player.dspeed
	local center_range= pdspeed.max - pdspeed.min
	local field_hahs= (field_height / arrow_height)
	local field_ahs= field_hahs * (center_range * .5)
	local ahs_per_second= screen_gameplay:GetTrueBPS(player.player_number) * player.dspeed_mult
	local fields_per_second= ahs_per_second / field_ahs
	if pdspeed.special then
		field_ahs= field_hahs * dspeed_default_range * .5
		fields_per_second= ahs_per_second / field_ahs
		local cen_dst_val, cen_dst_app= player.song_options:Centered(nil, dspeed_default_range * fields_per_second)
		if pdspeed.alternate then
			local suddoff_app= (suddmax - suddmin) / ((dspeed_default_max - dspeed_default_min) / cen_dst_app) * 3
			player.song_options:SuddenOffset(nil, suddoff_app)
		end
	else
		player.song_options:Centered(nil, center_range * fields_per_second)
	end
end

local function dspeed_halt(player)
	player.song_options:Centered(nil, 0)
	if player.dspeed.special and player.dspeed.alternate then
		player.song_options:SuddenOffset(nil, 0)
	end
end

local function dspeed_alternate(player)
	if player.current_options:Reverse() == 1 then
		player.song_options:Reverse(0)
		player.current_options:Reverse(0)
		local rev_tilt= -player.song_options:Tilt()
		player.song_options:Tilt(rev_tilt)
		player.current_options:Tilt(rev_tilt)
	else
		player.song_options:Reverse(1)
		player.current_options:Reverse(1)
		local rev_tilt= -player.song_options:Tilt()
		player.song_options:Tilt(rev_tilt)
		player.current_options:Tilt(rev_tilt)
	end
end

local function dspeed_reset(player)
	if player.dspeed.alternate then
		dspeed_alternate(player)
	end
	if player.dspeed.special then
		if player.dspeed.alternate then
			local cen= player.current_options:Centered()
			if cen < 1 then
				player.current_options:Centered(1)
			else
				player.current_options:Centered(dspeed_default_max)
			end
		else
			player.current_options:Centered(1)
		end
	else
		player.current_options:Centered(player.dspeed.min)
	end
end

local dspeed_special_phase_starts= {
	function(player)
		player.song_options:Reverse(1)
		player.current_options:Reverse(1)
		player.song_options:Centered(dspeed_default_max)
		player.current_options:Centered(dspeed_default_min)
		player.current_options:SuddenOffset(suddmax)
	end,
	function(player)
		player.song_options:Reverse(0)
		player.current_options:Reverse(0)
		player.current_options:SuddenOffset(.5)
	end,
}

local dspeed_special_phase_updates= {
	function(player)
		local cen= player.current_options:Centered()
		if cen >= 1 then
			player.dspeed_phase= 2
			dspeed_special_phase_starts[player.dspeed_phase](player)
		else
			dspeed_alternate(player)
		end
	end,
	function(player)
		local cen= player.current_options:Centered()
		if cen >= dspeed_default_max then
			player.dspeed_phase= 1
			dspeed_special_phase_starts[player.dspeed_phase](player)
		else
			dspeed_alternate(player)
		end
	end
}

local already_spewed= true
local spin_screen= true
local spin_value= 0
local update_spin= 2
local function Update(self)
	if not already_spewed then
		local top_screen= SCREENMAN:GetTopScreen()
		Trace("Top screen children.")
		if top_screen then
			local top_parent= top_screen:GetParent()
			local prev_top_parent= top_parent
			Trace("Climbing tree to find parents.")
			while top_parent do
				Trace(top_parent:GetName())
				prev_top_parent= top_parent
				top_parent= top_parent:GetParent()
			end
			top_parent= prev_top_parent
			if top_parent then
				rec_print_children(top_parent, "")
			else
				rec_print_children(top_screen, "")
			end
			already_spewed= true
		end
	end
	if gameplay_start_time == -20 then
		if GAMESTATE:GetCurMusicSeconds() >= 0 then
			gameplay_start_time= get_screen_time()
		end
	else
		gameplay_end_time= get_screen_time()
	end
	local enabled_players= GAMESTATE:GetEnabledPlayers()
	local curstats= STATSMAN:GetCurStageStats()
	if not curstats then
		Trace("SGbg.Update:  curstats is nil.")
	end
	song_progress_bar:update()
	for k, v in pairs(enabled_players) do
		local unmine_time= cons_players[v].unmine_time
		if unmine_time and unmine_time <= get_screen_time() then
			cons_players[v].mine_effect.unapply(v)
			cons_players[v].unmine_time= nil
		end
		local speed_info= cons_players[v]:get_speed_info()
		if speed_info.mode == "CX" and screen_gameplay.GetTrueBPS then
			local this_bps= screen_gameplay:GetTrueBPS(v)
			if speed_info.prev_bps ~= this_bps and this_bps > 0 then
				speed_info.prev_bps= this_bps
				local xmod= (speed_info.speed) / (this_bps * 60)
				cons_players[v].song_options:XMod(xmod)
				cons_players[v].current_options:XMod(xmod)
			end
		end
		if speed_info.mode == "D" then
			local this_bps= screen_gameplay:GetTrueBPS(v)
			local song_pos= GAMESTATE:GetPlayerState(v):GetSongPosition()
			local discard, approach= cons_players[v].song_options:Centered()
			if approach == 0 then
				if not song_pos:GetFreeze() and not song_pos:GetDelay() then
					dspeed_start(cons_players[v])
				end
			else
				if song_pos:GetFreeze() or song_pos:GetDelay() then
					dspeed_halt(cons_players[v])
				end
			end
			if speed_info.prev_bps ~= this_bps and this_bps > 0 then
				speed_info.prev_bps= this_bps
				dspeed_start(cons_players[v])
			end
			if cons_players[v].dspeed.special then
				if cons_players[v].dspeed.alternate then
					dspeed_special_phase_updates[cons_players[v].dspeed_phase](cons_players[v])
				else
					dspeed_alternate(cons_players[v])
					if cons_players[v].current_options:Centered() >= dspeed_default_max then
						dspeed_reset(cons_players[v])
					end
				end
			else
				if cons_players[v].current_options:Centered() >= cons_players[v].dspeed.max then
					dspeed_reset(cons_players[v])
				end
			end
		end
		if (side_swap_vals[v] or 0) > 1 then
			if side_toggles[v] then
				side_actors[v]:x(player_sides[v])
			else
				side_actors[v]:x(swap_on_xs[v])
			end
			side_toggles[v]= not side_toggles[v]
		end
		local pstats= curstats:GetPlayerStageStats(v)
		if not pstats then
			Trace("SGbg.Update:  pstats for " .. v .. " is nil.")
		end
		for fk, fv in pairs(feedback_things[v]) do
			if fv.update then fv:update(pstats) end
		end
	end
end

local author_centers= {
	[PLAYER_1]= { SCREEN_RIGHT * .25, SCREEN_TOP + (line_spacing*1.5) },
	[PLAYER_2]= { SCREEN_RIGHT * .75, SCREEN_TOP + (line_spacing*1.5) }
}

local function make_special_actors_for_players()
	local enabled_players= GAMESTATE:GetEnabledPlayers()
	local args= { Name= "special_actors",
								OnCommand= cmd(SetUpdateFunction,Update)
              }
	for k, v in pairs(enabled_players) do
		local add_to_feedback= {}
		if cons_players[v].flags.sigil then
			add_to_feedback[#add_to_feedback+1]= {
				name= "sigil", meattable= sigil_feedback_interface_mt,
				center= {sigil_centers[v][1], sigil_centers[v][2]}}
		end
		if cons_players[v].flags.judge then
			add_to_feedback[#add_to_feedback+1]= {
				name= "judge_list", meattable= judge_feedback_interface_mt,
				center= {judge_centers[v][1], judge_centers[v][2]}}
		end
		if cons_players[v].flags.score_meter then
			add_to_feedback[#add_to_feedback+1]= {
				name= "scoremeter", meattable= score_feedback_interface_mt,
				center= {score_feedback_centers[v][1], score_feedback_centers[v][2]}}
		end
		if cons_players[v].flags.dance_points then
			add_to_feedback[#add_to_feedback+1]= {
				name= "dp", meattable= dance_points_feedback_interface_mt,
				center= {dp_feedback_centers[v][1], dp_feedback_centers[v][2]}}
		end
		if cons_players[v].flags.bpm_meter then
			add_to_feedback[#add_to_feedback+1]= {
				name= "bpm", meattable= bpm_feedback_interface_mt,
				center= {bpm_centers[v][1], bpm_centers[v][2]}}
		end
		local a= {Name= v}
		for fk, fv in pairs(add_to_feedback) do
			local new_feedback= {}
			setmetatable(new_feedback, fv.meattable)
			a[#a+1]= new_feedback:create_actors(fv.name, fv.center[1], fv.center[2], v)
			feedback_things[v][#feedback_things[v]+1]= new_feedback
		end
		if cons_players[v].flags.chart_info then
			local cur_steps= gamestate_get_curr_steps(v)
			local author= steps_get_author(cur_steps)
			if GAMESTATE:IsCourseMode() then
				author= GAMESTATE:GetCurrentCourse():GetScripter()
			end
			if not author or author == "" then
				author= "Uncredited"
			end
			local difficulty= steps_to_string(cur_steps)
			local rating= cur_steps:GetMeter()
			local info_text= author .. ": " .. difficulty .. ": " .. rating
			a[#a+1]= normal_text(
				"author", info_text, solar_colors.f_text(),
				author_centers[v][1], author_centers[v][2], 1, center,
				{ OnCommand= function(self)
											 width_limit_text(self, spb_width/2 - 48)
										 end })
		end
		args[#args+1]= Def.ActorFrame(a)
	end
	args[#args+1]= normal_text(
		"songtitle", "", solar_colors.f_text(), SCREEN_CENTER_X,
		SCREEN_BOTTOM - (line_spacing*2), 1, center, {
			OnCommand= cmd(playcommand, "Set"),
			CurrentSongChangedMessageCommand= cmd(playcommand, "Set"),
			SetCommand=
				function(self)
					local cur_song= GAMESTATE:GetCurrentSong()
					if cur_song then
						local title= cur_song:GetDisplayFullTitle()
						self:settext(title)
						width_limit_text(self, spb_width)
					end
				end
		})
	args[#args+1]= song_progress_bar:create_actors()
	return Def.ActorFrame(args)
end

local function find_read_bpm_for_player_steps(player_number)
	if GAMESTATE:GetCurrentSong():IsDisplayBpmConstant() then
		local max_bpm= GAMESTATE:GetCurrentSteps(player_number):GetDisplayBpms()[2]
		return max_bpm
	else
		local timing_data= GAMESTATE:GetCurrentSteps(player_number):GetTimingData()
		local bpmsand= timing_data:GetBPMsAndTimes()
		if type(bpmsand[1]) == "string" then
			for i, s in ipairs(bpmsand) do
				local sand= split("=", s)
				bpmsand[i]= {tonumber(sand[1]), tonumber(sand[2])}
			end
		end
		local totals= {}
		local num_beats= timing_data:GetBeatFromElapsedTime(GAMESTATE:GetCurrentSong():GetLastSecond())
		local highest_sustained= 0
		local sustain_limit= 32
		for i, s in ipairs(bpmsand) do
			local end_beat= 0
			if bpmsand[i+1] then
				end_beat= bpmsand[i+1][1]
			else
				end_beat= num_beats
			end
			local len= (end_beat - s[1])
			if s[2] > highest_sustained and len > sustain_limit then
				highest_sustained= s[2]
			end
			totals[s[2]]= len + (totals[s[2]] or 0)
		end
		local tot= 0
		local most_common= false
		for k, v in pairs(totals) do
			local minutes_duration= v / k
			if not most_common or minutes_duration > most_common[2] then
				most_common= {k, minutes_duration}
			end
			tot= tot + (k * v)
		end
		local average= tot / num_beats
		local max_bpm= most_common[1]
		return max_bpm
	end
end

local mods_before_mine= {}
local function set_speed_from_speed_info(player)
	-- mmods are just a poor mask over xmods, so if you set an mmod in
	-- the middle of the song, it'll null out.  This means that if you
	-- use PlayerState:SetPlayerOptions, it'll ruin whatever mmod the
	-- player has set.  So this code is here to remove that mask.
	local speed_info= player:get_speed_info()
	speed_info.prev_bps= nil
	local mode_functions= {
		x= function(speed)
				 player.song_options:XMod(speed)
				 player.current_options:XMod(speed)
			 end,
		C= function(speed)
				 player.song_options:CMod(speed)
				 player.current_options:CMod(speed)
			 end,
		m= function(speed)
				 local read_bpm= find_read_bpm_for_player_steps(player.player_number)
				 local real_speed= (speed / read_bpm) / rate_coordinator:get_current_rate()
				 player.song_options:XMod(real_speed)
				 player.current_options:XMod(real_speed)
				 --player.song_options:MMod(speed)
				 --player.current_options:MMod(speed)
			 end,
		D= function(speed)
				 local read_bpm= find_read_bpm_for_player_steps(player.player_number)
				 local real_speed= (speed / read_bpm) / rate_coordinator:get_current_rate()
				 player.dspeed_mult= real_speed
				 player.song_options:XMod(real_speed)
				 if math.abs(player.dspeed.max - player.dspeed.min) < .01 then
					 player.dspeed.special= true
					 if player.dspeed.alternate then
						 player.current_options:Sudden(1)
						 player.song_options:Sudden(1)
						 player.song_options:SuddenOffset(suddmin)
						 player.dspeed_phase= 1
						 dspeed_special_phase_starts[player.dspeed_phase](player)
					 else
						 player.song_options:Centered(dspeed_default_max)
					 end
				 else
					 player.dspeed.special= false
					 player.song_options:Centered(player.dspeed.max)
				 end
			 end
	}
	if mode_functions[speed_info.mode] then
		mode_functions[speed_info.mode](speed_info.speed)
	end
end

local function cleanup(self)
	prev_song_end_timestamp= hms_timestamp()
	local time_spent= gameplay_end_time - gameplay_start_time
	for i, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
		cons_players[pn].credit_time= (cons_players[pn].credit_time or 0) + time_spent
	end
	reduce_time_remaining(time_spent)
	set_last_song_time(time_spent)
end

local function note_date_edit_test()
	local top_screen= SCREENMAN:GetTopScreen()
	for i, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
		local pinfo= top_screen:GetPlayerInfo(pn)
		if pinfo then
			Trace("Got pinfo, attempting to get note data.")
			local note_data= pinfo:GetNoteData()
			if note_data then
				Trace("Got note_data, hold onto your butts.")
				local tap_note= false
				local function lengthen_holds(tapnote, row, track)
					if not tap_note then tap_note= tapnote end
					if tapnote:GetType() == "TapNoteType_HoldHead" then
						local new_duration= tapnote:GetDuration()+2
						Trace("Setting held at " .. row .. " to " .. new_duration)
						tapnote:SetDuration(new_duration)
					end
				end
				note_data:ForEachTapNoteAllTracks(0, -1, lengthen_holds)
				--note_data:SetTapNote(2, 99, tap_note)
				--note_data:AddHoldNote(
				--	2, 100, {
				--		Type= "TapNoteType_HoldHead", SubType= "TapNoteSubType_Roll",
				--		Duration= 3})
			end
		end
	end
end

return Def.ActorFrame {
	Name= "SGPbgf",
	InitCommand=
		function(self)
			--Trace("SGPD OnCommand.")
			find_special_actors(self)
		end,
	--Def.Quad{InitCommand=cmd(FullScreen;diffuse,solar_colors.yellow())},
	make_special_actors_for_players(),
	Def.Actor{
		Name= "timer actor",
		InitCommand= function(self)
									 self:effectperiod(2^16)
									 timer_actor= self
								 end,
	},
	Def.Actor{
		Name= "Cleaner S22",
		OnCommand=
			function(self)
				screen_gameplay= SCREENMAN:GetTopScreen()
				if not screen_gameplay.GetTrueBPS then
					Trace("screen_gameplay lacks GetTrueBPS, something is wrong.")
				else
					screen_gameplay:HasteLifeSwitchPoint(.5)
					screen_gameplay:HasteTimeBetweenUpdates(4)
					screen_gameplay:HasteAddAmounts({-.25, 0, .25})
					screen_gameplay:HasteTurningPoints({-1, 0, 1})
				end
				--note_date_edit_test()
				song_progress_bar:set_from_song()
				local song_ops= GAMESTATE:GetSongOptionsObject("ModsLevel_Current")
				if song_ops:MusicRate() < 1 or song_ops:Haste() < 0 then
					song_ops:SaveScore(false)
				else
					song_ops:SaveScore(true)
				end
				local enabled_players= GAMESTATE:GetEnabledPlayers()
				prev_song_start_timestamp= hms_timestamp()
				local force_swap= (cons_players[PLAYER_1].side_swap or 0) > 1 or
					(cons_players[PLAYER_2].side_swap or 0) > 1
				for k, v in pairs(enabled_players) do
					cons_players[v].prev_steps= gamestate_get_curr_steps(v)
					cons_players[v]:stage_stats_reset()
					cons_players[v]:combo_qual_reset()
					cons_players[v].unmine_time= nil
					local speed_info= cons_players[v].speed_info
					if speed_info then
						speed_info.prev_bps= nil
					end
					set_speed_from_speed_info(cons_players[v])
					if cons_players[v].side_swap or force_swap then
						side_swap_vals[v]= cons_players[v].side_swap or
							cons_players[other_player[v]].side_swap
						local mod_res= side_swap_vals[v] % 1
						if mod_res == 0 then mod_res= 1 end
						swap_on_xs[v]= player_sides[v] + (side_diffs[v] * mod_res)
						side_actors[v]=
							screen_gameplay:GetChild("Player" .. ToEnumShortString(v))
						side_actors[v]:x(swap_on_xs[v])
						side_toggles[v]= true
					end

					--local ps= GAMESTATE:GetPlayerState(v)
					--local ops= ps:GetPlayerOptionsString("ModsLevel_Song")
					--Trace("pops: " .. ops)
					--ps:SetPlayerOptions("ModsLevel_Song", ops)
				end
			end,
		OffCommand= cleanup,
		CancelCommand= cleanup,
		CurrentSongChangedMessageCommand=
			function(self, param)
				song_progress_bar:set_from_song()
			end,
		CurrentStepsP1ChangedMessageCommand=
			function(self, param)
				set_speed_from_speed_info(cons_players[PLAYER_1])
			end,
		CurrentStepsP2ChangedMessageCommand=
			function(self, param)
				set_speed_from_speed_info(cons_players[PLAYER_2])
			end,
		JudgmentMessageCommand=
			function(self, param)
				if param.TapNoteScore == "TapNoteScore_HitMine" then
					local cp= cons_players[param.Player]
					if cp.mine_effect then
						cp.mine_effect.apply(param.Player)
						if not cp.unmine_time then
							cp.unmine_time= get_screen_time()
						end
						cp.unmine_time= cp.unmine_time + cp.mine_effect.time
					end
				end
			end,
	}
}
