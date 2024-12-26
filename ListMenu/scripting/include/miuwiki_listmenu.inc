/** Double-include prevention */
#if defined _miuwiki_listmenu_included_
  #endinput
#endif
#define _miuwiki_listmenu_included_

enum struct ListData
{
  char name[128];
  char description[128];
	StringMap passdata;
}

methodmap ListMenu{
  /**
   * Create a list menu.
   * 
   * @return        A panel handle with type ListMenu.
   */
  public native ListMenu();

  /**
   * Set Title for list menu.
   * 
   * @param title Title for list menu.
   * @param ...   Format arguments.
   * 
   */
  public native void SetTitle(const char[] title);

  /**
   * Add an Item for list menu.
   * 
   * @param name        The name of this item.
   * @param description The description of this item.
   * @param data        The StringMap handle to pass the data to list menu. If no extra data to pass that ignore it.
   * 
   * @note              name and description maxlength is 128!
   *                    if no extra data need to pass, set data to INVALID_HANDLE.
   * 
   * @note              listmenu plugin manager the handle of StringMap, so don't delete it after this function.
   * @note              listmenu plugin doesn't consider handle in StringMap, so please don't add Handle in it.
   *                    or you will get memory leak since handle doesn't free.
   * 
   * @return            The index of this item in it's list menu. 
   */
  public native void AddItem(const char[] name, const char[] description, StringMap data = view_as<StringMap>(INVALID_HANDLE));

  /**
   * Send a list menu to client.
   * 
   * @param client The client index to send.
   * @param time   How many time will menu show.
   * 
   * @return The index of this item in it's list menu.
   */
  public native void Send(int client, ListMenuHandler handler, int time);
}

typeset ListMenuHandler
{
  /**
   * Callback will trigger when client choose 1 - 7 index.
   * 8 - 10(0) index will not trigger this callback.
   * 
   * @param listmenu The listmenu handle of this menu.
   * @param client   client index.
   * @param index    index[0] is the index in this page.
   *                 index[1] is the index that this item in the hole item list.
   * @param item     the data that this index contain.
   * 
   * @note           listmenu plugin manager the handle of StringMap in ListData, so don't delete it after this function.
   * 
   */
  function void (int client, int index[2], ListData item);
};