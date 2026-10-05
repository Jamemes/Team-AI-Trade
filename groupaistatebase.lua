function GroupAIStateBase:is_ai_trade_possible()
	if managers.groupai:state():whisper_mode() then
		return false
	end
	if next(self._player_criminals) then
		return false
	end
	local ai_disabled = true
	for u_key, u_data in pairs(self._ai_criminals) do
		if u_data.status ~= "dead" and u_data.status ~= "disabled" then
			ai_disabled = false
			break
		end
	end
	return not ai_disabled and (self._hostage_headcount > 0 or next(self._converted_police) or managers.trade:is_trading())
end

function GroupAIStateBase:check_gameover_conditions()
	if not Network:is_server() or managers.platform:presence() ~= "Playing" then
		return false
	end
	if game_state_machine:current_state().game_ended and game_state_machine:current_state():game_ended() then
		return false
	end
	if Global.load_start_menu or Application:editor() then
		return false
	end
	local plrs_alive = false
	local plrs_disabled = true
	for u_key, u_data in pairs(self._player_criminals) do
		plrs_alive = true
		if u_data.status ~= "dead" and u_data.status ~= "disabled" then
			plrs_disabled = false
			break
		end
	end
	local ai_alive = false
	local ai_disabled = true
	for u_key, u_data in pairs(self._ai_criminals) do
		ai_alive = true
		if u_data.status ~= "dead" and u_data.status ~= "disabled" then
			ai_disabled = false
			break
		end
	end
	local gameover = false
	if not plrs_alive and not self:is_ai_trade_possible() then
		gameover = true
	elseif plrs_disabled and not ai_alive then
		gameover = true
	elseif plrs_disabled and ai_disabled then
		gameover = true
	end
	if gameover then
		if not self._gameover_clbk then
			self._gameover_clbk = callback(self, self, "_gameover_clbk_func")
			managers.enemy:add_delayed_clbk("_gameover_clbk", self._gameover_clbk, Application:time() + 10)
		end
	elseif self._gameover_clbk then
		managers.enemy:remove_delayed_clbk("_gameover_clbk")
		self._gameover_clbk = nil
	end
	return gameover
end

old_GroupAIStateBase_determine_objective_for_criminal_AI = old_GroupAIStateBase_determine_objective_for_criminal_AI or GroupAIStateBase._determine_objective_for_criminal_AI

function GroupAIStateBase:_determine_objective_for_criminal_AI(unit)
	local objective, closest_dis, closest_record
	local ai_pos = (self._ai_criminals[unit:key()] or self._police[unit:key()]).m_pos
	for pl_key, pl_record in pairs(self._player_criminals) do
		if pl_record.status ~= "dead" then
			local my_dis = mvector3.distance(ai_pos, pl_record.m_pos)
			if not closest_dis or closest_dis > my_dis then
				closest_dis = my_dis
				closest_record = pl_record
			end
		end
	end
	if closest_record then
		objective = {
			type = "follow",
			scan = true,
			follow_unit = closest_record.unit,
			is_default = true
		}
	end
	local ai_pos = (self._ai_criminals[unit:key()] or self._police[unit:key()]).m_pos
	local skip_hostage_trade_time_reset
	if not objective and self:is_ai_trade_possible() then
		local guard_time = managers.trade:get_guard_hostage_time()
		if 6 < guard_time then
			local hostage = managers.trade:get_best_hostage(ai_pos)
			skip_hostage_trade_time_reset = hostage
			if hostage and mvector3.distance(ai_pos, hostage.m_pos) > 1500 then
				self._guard_hostage_trade_time_map = self._guard_hostage_trade_time_map or {}
				local time = Application:time()
				local unit_key = unit:key()
				local last_time = self._guard_hostage_trade_time_map[unit_key]
				if not last_time or time > last_time + 7 then
					self._guard_hostage_trade_time_map[unit_key] = time
					return {
						type = "free",
						nav_seg = hostage.tracker:nav_segment(),
						stance = "hos",
						interrupt_dis = 300,
						scan = true
					}
				end
			end
		end
	end
	if not skip_hostage_trade_time_reset then
		self._guard_hostage_trade_time_map = nil
	end
	return objective
end