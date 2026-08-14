declare const useEventListener: <TEvent extends string, Thandler>(emitter: {
    on(event: TEvent, callback: Thandler): () => void;
} | null, eventName: TEvent, handler: any) => void;
export default useEventListener;
//# sourceMappingURL=useEventListener.d.ts.map