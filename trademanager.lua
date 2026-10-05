TradeManager.TRADE_DELAY = 5
function TradeManager:update(t, dt)
	self._t = t
	if not managers.criminals or not managers.hud then
		return
	end
	local is_trade_allowed = self:is_trade_allowed()
	local is_auto_assault_ai_trade = self:update_auto_assault_ai_trade(dt, is_trade_allowed)
	if not self._hostage_remind_t or t > self._hostage_remind_t then
		if not self._trading_hostage and not self._hostage_trade_clbk and #self._criminals_to_respawn > 0 and 0 >= managers.groupai:state():hostage_count() and not next(managers.groupai:state():all_converted_enemies()) and managers.groupai:state():is_AI_enabled() and managers.groupai:state():bain_state() then
			local cable_tie_data = managers.player:has_special_equipment("cable_tie")
			if cable_tie_data and 0 < Application:digest_value(cable_tie_data.amount, false) then
				managers.dialog:queue_dialog("ban_h01x", {})
			elseif self:get_criminal_to_trade(true) ~= nil then
				managers.dialog:queue_dialog("Play_ban_h22x", {})
			end
		end
		self._hostage_remind_t = t + math.random(60, 120)
	end
	self._trade_counter_tick = self._trade_counter_tick - dt
	if 0 >= self._trade_counter_tick then
		self._trade_counter_tick = self._trade_counter_tick + 1
		if self._hostage_to_trade and not alive(self._hostage_to_trade.unit) then
			self:cancel_trade()
		end
		for _, crim in ipairs(self._criminals_to_respawn) do
			local crim_data = managers.criminals:character_data_by_name(crim.id)
			local mugshot_id = crim_data and crim_data.mugshot_id
			local mugshot_data = mugshot_id and managers.hud:_get_mugshot_data(mugshot_id)
			if mugshot_data and not mugshot_data.state_name ~= "mugshot_in_custody" then
				managers.hud:set_mugshot_custody(mugshot_id)
				if 0 < crim.respawn_penalty then
				end
			end
			if 0 < crim.respawn_penalty then
				crim.respawn_penalty = (self._trade_countdown or managers.groupai:state():is_ai_trade_possible()) and crim.respawn_penalty - 1 or crim.respawn_penalty
				if 0 >= crim.respawn_penalty then
					crim.respawn_penalty = 0
				end
			end
		end
	end
	if (self._trade_countdown or is_auto_assault_ai_trade) and is_trade_allowed then
		local trade = self:get_criminal_to_trade(true)
		local is_ai_trade_possible = managers.groupai:state():is_ai_trade_possible()
		if trade and Global.game_settings.single_player and not trade.ai and not is_ai_trade_possible then
			trade = nil
		end
		if trade then
			self:_increment_trade_index()
			if is_ai_trade_possible then
				self:clbk_begin_hostage_trade_dialog(1)
			else
				local respawn_t = self._t + math.random(2, 5)
				self._hostage_trade_clbk = "TradeManager"
				managers.enemy:add_delayed_clbk(self._hostage_trade_clbk, callback(self, self, "clbk_begin_hostage_trade_dialog", 1), respawn_t)
			end
		end
	end
end

function TradeManager:clbk_begin_hostage_trade()
	self._hostage_trade_clbk = nil
	self:_send_begin_trade(self._criminals_to_respawn[1])
	local possible_criminals, is_instant_trade = self:get_possible_criminals()
	local rescuing_criminal = possible_criminals[math.random(1, #possible_criminals)]
	rescuing_criminal = managers.groupai:state():all_criminals()[rescuing_criminal]
	local rescuing_criminal_pos
	if rescuing_criminal then
		rescuing_criminal_pos = rescuing_criminal.m_pos
	else
		managers.groupai:state():check_gameover_conditions()
		managers.enemy:add_delayed_clbk(self._hostage_trade_clbk, callback(self, self, "clbk_begin_hostage_trade"), self._t + 5)
		return
	end
	local best_hostage = self:get_best_hostage(rescuing_criminal_pos)
	if best_hostage then
		self._trading_hostage = true
		self._hostage_to_trade = best_hostage
		best_hostage.unit:brain():set_logic("trade")
		local clbk_key = "TradeManager"
		self._hostage_to_trade.death_clbk_key = clbk_key
		self._hostage_to_trade.destroyed_clbk_key = clbk_key
		best_hostage.unit:character_damage():add_listener(clbk_key, {"death"}, callback(self, self, "clbk_hostage_died"))
		best_hostage.unit:base():add_destroy_listener(clbk_key, callback(self, self, "clbk_hostage_destroyed"))
		if is_instant_trade then
			self._auto_assault_ai_trade_t = nil
			best_hostage.unit:interaction():interact(rescuing_criminal.unit)
		end
		if not rescuing_criminal then
		end
	else
		self:cancel_trade()
	end
end

function TradeManager:update_auto_assault_ai_trade(dt, is_trade_allowed)
	if self._auto_assault_ai_trade_t then
		self._auto_assault_ai_trade_t = self._auto_assault_ai_trade_t - dt
	end
	if not Network:is_server() then
		return false
	end
	if not is_trade_allowed or self._trade_countdown or not managers.groupai:state():is_ai_trade_possible() then
		if not self:is_trading() then
			self:_set_auto_assault_ai_trade(nil, 0)
		end
		return false
	end
	local min_crim = self:get_min_criminal_to_trade()
	if not min_crim then
		Application:error("AI trade possible even though no one to trade.\n", inspect(self._criminals_to_respawn))
		return false
	end
	if not self._auto_assault_ai_trade_t then
		self._auto_assault_ai_trade_t = tweak_data.player.damage.automatic_assault_ai_trade_time
	end
	local time = self._auto_assault_ai_trade_t + math.max(0, min_crim.respawn_penalty)
	time = math.min(time, tweak_data.player.damage.automatic_assault_ai_trade_time_max)
	self:_set_auto_assault_ai_trade(min_crim.id, time)
	return time <= self.TRADE_DELAY
end

function TradeManager:get_min_criminal_to_trade()
	local min_crim
	for _, crim in ipairs(self._criminals_to_respawn) do
		if not crim.ai and (not min_crim or min_crim.respawn_penalty > crim.respawn_penalty) then
			min_crim = crim
		end
	end
	return min_crim
end

function TradeManager:_set_auto_assault_ai_trade(character_name, time)
	if self._auto_assault_ai_trade_criminal_name ~= character_name then
		self._auto_assault_ai_trade_criminal_name = character_name
		if managers.network and not Global.game_settings.single_player then
			managers.network:session():send_to_peers_synched("set_auto_assault_ai_trade", character_name, time)
		end
	end
end

function TradeManager:sync_set_auto_assault_ai_trade(character_name, time)
	self._auto_assault_ai_trade_criminal_name = character_name
	self._auto_assault_ai_trade_t = time
end

function TradeManager:get_auto_assault_ai_trade_time()
	if not self._trade_countdown and managers.criminals:local_character_name() == self._auto_assault_ai_trade_criminal_name and managers.groupai:state():is_ai_trade_possible() then
		return self._auto_assault_ai_trade_t
	else
		return nil
	end
end

function TradeManager:get_possible_criminals()
	local possible_criminals = {}
	for u_key, u_data in pairs(managers.groupai:state():all_player_criminals()) do
		if u_data.status ~= "dead" then
			table.insert(possible_criminals, u_key)
		end
	end
	local is_instant_trade
	if #possible_criminals == 0 then
		is_instant_trade = true
		for u_key, u_data in pairs(managers.groupai:state():all_AI_criminals()) do
			if u_data.status ~= "dead" and u_data.status ~= "disabled" then
				table.insert(possible_criminals, u_key)
			end
		end
	end
	return possible_criminals, is_instant_trade
end

function TradeManager:get_guard_hostage_time()
	local min_crim = self:get_min_criminal_to_trade()
	local penalty = min_crim and min_crim.respawn_penalty or 0
	local guard_time = (self._auto_assault_ai_trade_t or 0) + penalty
	local automatic_respawn_time = tweak_data.player.damage.automatic_respawn_time
	if automatic_respawn_time then
		return math.min(automatic_respawn_time, guard_time)
	else
		return guard_time
	end
end

function TradeManager:is_trade_allowed()
	return Network:is_server() and not self._trading_hostage and not self._hostage_trade_clbk and #self._criminals_to_respawn > 0 and not managers.groupai:state():whisper_mode() and not self._speaker_snd_event and (0 < managers.groupai:state():hostage_count() or next(managers.groupai:state():all_converted_enemies()))
end

function TradeManager:is_trading()
	return (self._trading_hostage or self._hostage_trade_clbk or self._speaker_snd_event) and #self._criminals_to_respawn > 0
end

function TradeManager:get_best_hostage(pos)
	local civilians = managers.enemy:all_civilians()
	local trade_dist = tweak_data.group_ai.optimal_trade_distance
	local optimal_trade_dist = math.random(trade_dist[1], trade_dist[2])
	optimal_trade_dist = optimal_trade_dist * optimal_trade_dist
	local best_hostage_d, best_hostage
	for _, h_key in ipairs(managers.groupai:state():all_hostages()) do
		local civ = civilians[h_key]
		if civ and civ.unit:character_damage():pickup() then
			civ = nil
		end
		local hostage = civ or managers.enemy:all_enemies()[h_key]
		if hostage then
			local d = math.abs(mvector3.distance_sq(hostage.m_pos, pos) - optimal_trade_dist)
			if civ then
				d = d * 0.5
			end
			if not best_hostage_d or best_hostage_d > d then
				best_hostage_d = d
				best_hostage = hostage
			end
		end
	end
	if not best_hostage then
		for u_key, unit in pairs(managers.groupai:state():all_converted_enemies()) do
			best_hostage = managers.enemy:all_enemies()[u_key]
		end
	end
	return best_hostage
end