/**
* Copyright: Copyright Auburn Sounds 2015 and later.
* License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
* Authors:   Guillaume Piolat
*/
module dplug.gui.toolkit.dirtylist;

import gfm.math;

import dplug.core.alignedbuffer;
import dplug.core.unchecked_sync;

import dplug.gui.boxlist;

final class DirtyRectList
{
public:

    this()
    {
        _dirtyRectMutex = new UncheckedMutex();
        _dirtyRects = new AlignedBuffer!box2i(4);
    }

    ~this()
    {
        close();
    }

    void close()
    {
        _dirtyRectMutex.close();
        _dirtyRects.close();
    }

    bool isEmpty() nothrow @nogc
    {
        _dirtyRectMutex.lock();
        scope(exit) _dirtyRectMutex.unlock();
        return _dirtyRects.length == 0;
    }

    /// Returns: Array of rectangles in the list, remove them from the list.
    /// Needed to avoid races in repainting.
    void pullAllRectangles(AlignedBuffer!box2i result) nothrow @nogc
    {
        _dirtyRectMutex.lock();
        scope(exit) _dirtyRectMutex.unlock();

        foreach(rect; _dirtyRects[])
            result.pushBack(rect);

        _dirtyRects.clearContents();
    }

    /// Add a rect while keeping the no overlap invariant
    void addRect(box2i rect) nothrow @nogc
    {
        assert(rect.isSorted);

        if (!rect.empty)
        {
            _dirtyRectMutex.lock();
            scope(exit) _dirtyRectMutex.unlock();

            bool processed = false;

            for (int i = 0; i < _dirtyRects.length; ++i)
            {
                box2i other = _dirtyRects[i];
                if (other.contains(rect))
                {
                    // If the rectangle candidate is inside an element of the list, discard it.
                    processed = true;
                    break;
                }
                else if (rect.contains(other)) // remove rect that it contains
                {
                    // If the rectangle candidate contains an element of the list, this element need to go.
                    _dirtyRects[i] = _dirtyRects.popBack();
                    i--;
                }
                else
                {
                    box2i common = other.intersection(rect);
                    if (!common.empty())
                    {
                        // compute other without common
                        box2i D, E, F, G;
                        boxSubtraction(other, common, D, E, F, G);  

                        // remove other from list
                        _dirtyRects[i] = _dirtyRects.popBack();
                        i--;

                        // push the sub parts at the end of the list
                        // this is guaranteed to be non-overlapping since the list was non-overlapping before
                        if (!D.empty) _dirtyRects.pushBack(D);
                        if (!E.empty) _dirtyRects.pushBack(E);
                        if (!F.empty) _dirtyRects.pushBack(F);
                        if (!G.empty) _dirtyRects.pushBack(G);
                    }
                    // else no intersection problem, the candidate rectangle will be pushed normally in the list
                }

            }

            if (!processed)
                _dirtyRects.pushBack(rect);

            assert(haveNoOverlap(_dirtyRects[]));
        }       

    }

private:
    /// The possibly overlapping areas that need updating.
    AlignedBuffer!box2i _dirtyRects;

    /// This is protected by a mutex, because it is sometimes updated from the host.
    UncheckedMutex _dirtyRectMutex;
}

