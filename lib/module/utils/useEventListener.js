"use strict";

import { useEffect } from 'react';
const useEventListener = (emitter, eventName, handler) => {
  useEffect(() => emitter && handler ? emitter.on(eventName, handler) : () => {}, [emitter, eventName, handler]);
};
export default useEventListener;
//# sourceMappingURL=useEventListener.js.map