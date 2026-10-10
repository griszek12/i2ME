import javax.microedition.midlet.MIDlet;
import javax.microedition.lcdui.*;
import javax.microedition.rms.RecordStore;

public final class DemoMIDlet extends MIDlet {
    private DemoCanvas canvas;
    protected void startApp() {
        int launches = 1;
        try {
            RecordStore rs = RecordStore.openRecordStore("LegacyDemo", true);
            if (rs.getNumRecords() > 0) launches = (rs.getRecord(1)[0] & 255) + 1;
            byte[] value = {(byte)launches};
            if (rs.getNumRecords() == 0) rs.addRecord(value, 0, 1); else rs.setRecord(1, value, 0, 1);
            rs.closeRecordStore();
            System.out.println("[DEMO] RMS launch count=" + launches);
        } catch (Exception ex) { System.out.println("[DEMO] RMS ERROR " + ex); }
        canvas = new DemoCanvas(launches);
        Display.getDisplay(this).setCurrent(canvas);
        new Thread(canvas).start();
        System.out.println("[DEMO] started Java ME Canvas");
    }
    protected void pauseApp() {}
    protected void destroyApp(boolean unconditional) { if (canvas != null) canvas.running = false; }
    private static final class DemoCanvas extends Canvas implements Runnable {
        volatile boolean running = true;
        int frame, x = 100, y = 170, launches, lastKey;
        DemoCanvas(int count) { launches = count; setFullScreenMode(true); }
        protected void paint(Graphics g) {
            g.setColor(0x101B2D); g.fillRect(0,0,getWidth(),getHeight());
            g.setColor(0x49E2AD);g.drawString("Legacy J2ME",120,24,Graphics.HCENTER|Graphics.TOP);
            g.setColor(0xFFFFFF);g.drawString("MIDP 2.0 / CLDC 1.1",120,48,Graphics.HCENTER|Graphics.TOP);
            g.drawString("Java frames: " + frame,12,76,Graphics.LEFT|Graphics.TOP);
            g.drawString("RMS launches: " + launches,12,98,Graphics.LEFT|Graphics.TOP);
            g.drawString("Last key: " + lastKey,12,120,Graphics.LEFT|Graphics.TOP);
            g.setColor(0x4C9EFF);g.fillRoundRect(x,y,28,28,8,8);
            g.setColor(0x49E2AD);g.drawRect(8,150,getWidth()-16,getHeight()-188);
            g.setColor(0xFFFFFF);g.drawString("Move with arrows / 2 4 6 8",120,getHeight()-26,Graphics.HCENTER|Graphics.TOP);
        }
        protected void keyPressed(int key) {
            lastKey=key;
            if(key==-1||key=='2')y-=8;
            if(key==-2||key=='8')y+=8;
            if(key==-3||key=='4')x-=8;
            if(key==-4||key=='6')x+=8;
            x=Math.max(10,Math.min(getWidth()-40,x));y=Math.max(154,Math.min(getHeight()-68,y));
            System.out.println("[DEMO] key="+key+" x="+x+" y="+y);
        }
        public void run() {
            while(running) {
                frame++;repaint();
                if(frame==1||frame%100==0)System.out.println("[DEMO] rendered frames="+frame);
                try {Thread.sleep(50);}catch(InterruptedException ex){return;}
            }
        }
    }
}
