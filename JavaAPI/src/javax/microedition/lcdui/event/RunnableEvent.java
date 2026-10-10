/*
 * Copyright 2012 Kulikov Dmitriy
 * Copyright 2017 Nikita Shakarun
 * Ported for iOS/miniJVM — removed Android Toast/ContextHolder/ViewHandler.
 */
package javax.microedition.lcdui.event;

import javax.microedition.util.ArrayStack;

public class RunnableEvent extends Event {
	private static final ArrayStack<RunnableEvent> recycled = new ArrayStack<>();
	private static int queued;

	private Runnable runnable;

	public static Event getInstance(Runnable runnable) {
		RunnableEvent instance = recycled.pop();
		if (instance == null) {
			instance = new RunnableEvent();
		}
		instance.runnable = runnable;
		return instance;
	}

	@Override
	public void process() {
		runnable.run();
	}

	@Override
	public void recycle() {
		runnable = null;
		recycled.push(this);
	}

	@Override
	public void enterQueue() {
		if (++queued > 50 && EventQueue.isImmediate()) {
			EventQueue.setImmediate(false);
			System.out.println("[RunnableEvent] Immediate mode disabled due to stack overflow");
		}
	}

	@Override
	public void leaveQueue() {
		queued--;
	}

	@Override
	public boolean placeableAfter(Event event) {
		return true;
	}
}
