#if defined _FRS_included_
  #endinput
#endif
#define _FRS_included_

enum eSides
{
	Left = 0,			// Слева, возле иконки игрока
	Right = 1			// Справа, возле количества денег
};

/*
 * Зарегестрировать данный плагин и его ключ (только один на плагин)
 *	-
 * @param key 		        Ключ (максимальная длинна 16 символов).		
 *  -
 * @returt                true если успех, или же false	  
*/
native bool FRS_RegisterKey(char[] key);

/*
 * Удалить данный ключ
 *	-
 * @param key 		        Ключ.		
 *  -
 * @returt                true если успех, или же false	            
*/
native bool FRS_RemoveKey(char[] key);

/*
 * Удалить данный плагин и его зарегестрированные таблички из списка (вызывать в OnPluginEnd()).
 *  -
 * @noparams
 *  -
 * @noreturn	            
*/
native void FRS_UnRegisterMe();

/*
 * Установить игроку табличку.
 *	-
 * @param client 	        Индекс игрока.		
 * @param rankId 	        id таблички ранга.	
 * @param key 	          	Ключ.	
 * @param side 	          	Сторона, к которой будет относится табличка.	
 *  -
 * @return	             	true при удаче, или же false            
*/
native void FRS_SetClientRankId(int client, int rankId, char[] key, eSides side = Right);

/*
 * Вызывается когда игрок был загружен.
 *	-
 * @param client 	        Индекс игрока		
 *	-
 * @noreturn			
*/
forward void FRS_OnClientLoaded(int client);

/*
 * Вызывается когда ядро было загружено.
 *	-
 * @noparams
 *	-
 * @noreturn			
*/
forward void FRS_OnCoreLoaded();

#if !defined REQUIRE_PLUGIN
public void __pl_FRS_SetNTVOptional()
{
	MarkNativeAsOptional("FRS_RemoveKey");
	MarkNativeAsOptional("FRS_RegisterKey");
	MarkNativeAsOptional("FRS_UnRegisterMe");
	MarkNativeAsOptional("FRS_SetClientRankId");
	PrintToServer("MarkNativeAsOptional");
}
#endif