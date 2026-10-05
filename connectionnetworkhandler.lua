function ConnectionNetworkHandler:set_auto_assault_ai_trade(character_name, time)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end
	managers.trade:sync_set_auto_assault_ai_trade(character_name, time)
end