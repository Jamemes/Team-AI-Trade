Hooks:PostHook(IngameWaitingForRespawnState, "_begin_game_enter_transition", "Team_AI_Trade.IngameWaitingForRespawnState._begin_game_enter_transition", function(self)
	self._ai_trade_respawn_gui_enabled = nil
end)

function IngameWaitingForRespawnState:update(t, dt)
	if self._player_state_change_needed and not alive(managers.player:player_unit()) then
		self._player_state_change_needed = nil
		managers.player:set_player_state("standard")
	end
	local btn_stats_screen_press = not self._stats_screen and self._controller:get_input_pressed("stats_screen")
	local btn_stats_screen_release = self._stats_screen and self._controller:get_input_released("stats_screen")
	if btn_stats_screen_press then
		self._stats_screen = true
		managers.hud:show_stats_screen()
	elseif btn_stats_screen_release then
		self._stats_screen = false
		managers.hud:hide_stats_screen()
	end
	local ai_trade_time = managers.trade:get_auto_assault_ai_trade_time()
	if not ai_trade_time and self._ai_trade_respawn_gui_enabled then
		managers.hud:set_custody_timer_visibility(false)
		self._ai_trade_respawn_gui_enabled = false
	end
	if ai_trade_time and (not self._auto_respawn_t or self._auto_respawn_t - t > math.max(0, ai_trade_time)) and not self._ready_to_spawn_t then
		if not self._auto_respawn_t and not self._ai_trade_respawn_gui_enabled then
			managers.hud:set_custody_timer_visibility(true)
			self._ai_trade_respawn_gui_enabled = true
		end
		managers.hud:set_custody_respawn_type(true)
		managers.hud:set_custody_respawn_time(ai_trade_time)
	elseif self._auto_respawn_t then
		managers.hud:set_custody_respawn_type(false)
		managers.hud:set_custody_respawn_time(self._auto_respawn_t - t)
		if t > self._auto_respawn_t then
			self._auto_respawn_t = nil
			self:_begin_game_enter_transition()
		end
	elseif self._ready_to_spawn_t and t > self._ready_to_spawn_t then
		IngameWaitingForRespawnState.request_player_spawn()
	end
	if self._respawn_delay then
		self._respawn_delay = managers.trade:respawn_delay_by_name(managers.criminals:local_character_name())
		if 0 >= self._respawn_delay then
			self._respawn_delay = nil
			managers.hud:set_custody_negotiating_visible(false)
			managers.hud:set_custody_trade_delay_visible(false)
		else
			managers.hud:set_custody_trade_delay(self._respawn_delay)
		end
	end
	if self._play_too_long_line_t and t > self._play_too_long_line_t and managers.groupai:state():bain_state() then
		self._play_too_long_line_t = nil
		managers.dialog:queue_dialog("Play_ban_h38x", {})
	end
	self:_upd_watch(t, dt)
end
