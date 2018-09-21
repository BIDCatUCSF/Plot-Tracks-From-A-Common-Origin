%
%  Graphing of tracks from a common origin.
%
%  To make this tool available to Imaris, copy this file into the XTensions
%  folder in the Imaris installation folder, e.g., C:\Program
%  Files\Bitplane\Imaris x64 7.6.1\XTensions. After copying this file to
%  the XTensions folder and restarting Imaris, you can find this function
%  in the Surfaces Function menu, as well as in the Image Processing menu
%  under the Spots and Surfaces Functions groups.
%
%    <CustomTools>
%      <Menu>
%       <Submenu name="Surfaces Functions">
%        <Item name="Plot all tracks with a common origin" icon="Matlab"
%        tooltip="Graph tracks in Surpass Spots or Surfaces with a common origin.">
%          <Command>MatlabXT::plottrackscommonorigin(%i)</Command>
%        </Item>
%       </Submenu>
%       <Submenu name="Spots Functions">
%        <Item name="Plot all tracks with a common origin" icon="Matlab"
%        tooltip="Graph tracks in Surpass Spots or Surfaces with a common origin.">
%          <Command>MatlabXT::plottrackscommonorigin(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%
%      <SurpassTab>
%        <SurpassComponent name="bpSurfaces">
%          <Item name="Plot all tracks with a common origin" icon="Matlab"
%          tooltip="Graph tracks in Surpass Spots or Surfaces with a common origin.">
%            <Command>MatlabXT::plottrackscommonorigin(%i)</Command>
%          </Item>
%        </SurpassComponent>
%        <SurpassComponent name="bpSpots">
%          <Item name="Plot all tracks with a common origin" icon="Matlab"
%          tooltip="Graph tracks in Surpass Spots or Surfaces with a common origin.">
%            <Command>MatlabXT::plottrackscommonorigin(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
% 
%  Description: Plots spots or surfaces tracks from a common origin.
% 
%  Copyright 2013 - P. Beemiller. Licensed under a Creative Commmons
%  Attribution license. Please see: http://creativecommons.org/licenses/by/3.0/


function plottrackscommonorigin( xImarisID )
    % PLOTTRACKSCOMMONORIGIN Plot Surpass tracks with a common origin.
    %   PLOTTRACKSCOMMONORIGIN generates a graph of all tracks, with tracks
    %   shifted to have an origin at (0, 0, 0).
    %   
    %   The only input is the ID of the Imaris instance with the object
    %   tracks to be graphed. The function will create a list of the Spots
    %   and Surfaces present in the Surpass scene and prompt the user to
    %   select the object's tracks to plots. The resulting graph can be
    %   re-scaled, rotated, etc., then output as an image or vector art for
    %   presentation.
    
    %% Get the Imaris instance ID.
    % If the extension is compiled, the Imaris ID will be passed as a string.
    if ischar(xImarisID)
        xImarisID = str2double(xImarisID);
    end
    
    %% Append ImarisLib to the dynamic path. 
    if isempty(javaclasspath('-dynamic')) || ...
            cellfun(@isempty, regexp(javaclasspath('-dynamic'), 'ImarisLib.jar', 'Start', 'Once'))
        javaaddpath(['.' filesep 'ImarisLib.jar'])
    end
    
    %% Create a new object from the ImarisLib class.
    xImarisLib = ImarisLib;

    %% Connect to the calling Imaris instance.
    xImarisApp = xImarisLib.GetApplication(xImarisID);
    
    %% Get the Surpass Spots and Surfaces.
    surpassObjects = xtgetsporfaces(xImarisApp, 'Both');

    % If the scene has no Spots or Surfaces, return.
    if isempty(surpassObjects)
        return
    end % if
    
    %% Create a GUI to select objects.
    desktopPos = get(0, 'MonitorPositions');
    
    guiWidth = 230;
    guiHeight = 114;
    guiPos = [...
        (desktopPos(1, 3) - guiWidth)/2, ...
        (desktopPos(1, 4) - guiHeight)/2, ...
        guiWidth, ...
        guiHeight];
    
    guiCenteredPlots = figure(...
        'CloseRequestFcn', {@guiclosereqfcn}, ...
        'MenuBar', 'None', ...
        'Name', 'Centered plots', ...
        'NumberTitle', 'Off', ...
        'Position', guiPos, ...
        'Resize', 'Off', ...
        'Tag', 'guiCenteredPlots');
    
    % Create the object selection popup menu.
    uicontrol(...
        'Background', get(guiCenteredPlots, 'Color'), ...
        'FontSize', 12, ...
        'Foreground', 'k', ...
        'Parent', guiCenteredPlots, ...
        'Position', [10 66 108 24], ...
        'String', 'Spots|Surfaces', ...
        'Style', 'text', ...
        'Tag', 'textObjects')
        
    popupObjects = uicontrol(...
        'FontSize', 12, ...
        'Parent', guiCenteredPlots, ...
        'Position', [130 70 90 24], ...
        'Style', 'popupmenu', ...
        'String', {surpassObjects.Name}, ...
        'Tag', 'popupObjects', ...
        'TooltipString', 'Select objects to plot', ...
        'Value', 1);
    
    uicontrol(...
        'Callback', @(pushCalc, eventData)pushplotcallback(pushCalc, eventData), ...
        'FontSize', 12, ...
        'Parent', guiCenteredPlots, ...
        'Position', [130 20 90 24], ...
        'Style', 'pushbutton', ...
        'String', 'Plot', ...
        'Tag', 'pushPlot', ...
        'TooltipString', 'Plot centered tracks');
    
    %% Nested function to plot zero-centered tracks.
    function pushplotcallback(varargin)
        % PUSHPLOTCALLBACK Plot selected object tracks centered at [0, 0, 0].
        %
        %
        
        %% Get the selected object.
        plotObjectIdx = get(popupObjects, 'Value');
        xObject = surpassObjects(plotObjectIdx).ImarisObject;

        %% Get the Surpass object data.
        if xImarisApp.GetFactory.IsSpots(xObject)
            % Get the spot positions.
            objectPos = xObject.GetPositionsXYZ;

        else
            % Get the number of surfaces.
            surfaceCount = xObject.GetNumberOfSurfaces;

            % Get the surface positions and times.
            objectPos = zeros(surfaceCount, 3);
            for s = 1:surfaceCount
                objectPos(s, :) = xObject.GetCenterOfMass(s - 1);
            end % s

        end % if

        %% Allocate an array to collect all the recentered positions.
        centeredPos = zeros(size(objectPos));

        %% Get the track information.
        objectIDs = xObject.GetTrackIds;
        objectEdges = xObject.GetTrackEdges;
        trackLabels = unique(objectIDs);

        %% If there are no tracks, return.
        if isempty(objectEdges)
            return
        end % if
        
        %% Create a figure for plotting.
        % Set the figure size and position.
        guiCenteredPlotsPos = get(guiCenteredPlots, 'Position');
        
        figGraphWidth = 560;
        figGraphHeight = 420;
        figPos = [...
            guiCenteredPlotsPos(1) + 7
            guiCenteredPlotsPos(2) - figGraphHeight + 32
            figGraphWidth
            figGraphHeight];
        
        figGraph = figure(...
            'CloseRequestFcn', {@figgraphclosereqfcn}, ...
            'DockControls', 'off', ...
            'Name', [char(xObject.GetName) ' Tracks'], ...
            'NumberTitle', 'off', ...
            'Position', figPos, ...
            'Renderer', 'ZBuffer', ...
            'Tag', 'figGraph');
        
        axColor = 0.25*ones(3, 1);
        axesPlot = axes(...
            'FontSize', 12, ...
            'Linewidth', 2, ...
            'Parent', figGraph, ...
            'TickDir', 'out', ...
            'XColor', axColor, ...
            'YColor', axColor, ...
            'ZColor', axColor);
                
        %% Add the graph's handle to the base's graphChildren appdata.
        graphChildren = getappdata(guiCenteredPlots, 'graphChildren');
        
        % Append the window's handle to the list.
        graphChildren = [graphChildren; figGraph];
        
        % Update the appdata.
        setappdata(guiCenteredPlots, 'graphChildren', graphChildren)
        
        %% Translate all the tracks to a common origin and plot.
        % Create a color sequence for the lines.
        lineColors = lines(length(trackLabels));
        
        for r = 1:length(trackLabels)
            % Get indices for the track.
            rEdges = objectEdges(objectIDs == trackLabels(r), :);
            rSpots = unique(rEdges);

            % Get the track positions.
            rPos = objectPos(rSpots + 1, :);

            % Shift the track coordinates to place the origin at zero.
            cPos = bsxfun(@minus, rPos, rPos(1, :));

            % Add the centered coordinates to the list of all track positions.
            centeredPos(rSpots + 1, :) = cPos;

            % Plot the shifted track.
            line(cPos(:, 1), cPos(:, 2), cPos(:, 3), ...
                'Color', lineColors(r, :), ...
                'DisplayName', ['Track ' num2str(r)], ...
                'LineWidth', 1, ...
                'Parent', axesPlot) 
        end % for r
        
        %% Format the axes.
        axis(axesPlot, 'equal')
        
        % Make the axes symmetric about zero.
        % For x:
        xRange = xlim(axesPlot);
        xExtreme = max(abs(xRange));
        xlim(axesPlot, [-xExtreme xExtreme])
        
        % For y:
        yRange = ylim(axesPlot);
        yExtreme = max(abs(yRange));
        ylim(axesPlot, [-yExtreme yExtreme])
        
        % For z:
        zRange = zlim(axesPlot);
        zExtreme = max(abs(zRange));
        zlim(axesPlot, [-zExtreme zExtreme])
        
        %% Add lines to serve as coordinate axes.
        xAx = line(xlim, [0 0], [0 0], ...
            'Color', axColor, ...
            'DisplayName', 'X', ...
            'LineStyle', ':', ...
            'LineWidth', 2, ...
            'Parent', axesPlot);
        yAx = line([0 0], ylim, [0 0], ...
            'Color', axColor, ...
            'DisplayName', 'Y', ...
            'LineStyle', ':', ...
            'LineWidth', 2, ...
            'Parent', axesPlot);
        zAx = line([0 0], [0 0], zlim, ...
            'Color', axColor, ...
            'DisplayName', 'Z', ...
            'LineStyle', ':', ...
            'LineWidth', 2, ...
            'Parent', axesPlot);
        
        uistack([zAx, yAx, xAx], 'bottom')
        
        %% Label the axes with the Imaris units.
        imarisUnits = char(xImarisApp.GetDataSet.GetUnit);
        
        % If the units are in microns, add a slash for latex. I think Imaris
        % always uses microns, but just in case.
        if strcmp(imarisUnits, 'um') || isempty(imarisUnits)
            imarisUnits = '\mum';
        end % if
        
        xlabel(['x (' imarisUnits ')'], 'Color', axColor)
        ylabel(['y (' imarisUnits ')'], 'Color', axColor)
        zlabel(['z (' imarisUnits ')'], 'Color', axColor)
        
        %% Add a menu with choices for doing axes adjustments.
        % Create the menu.    
        menuAaxes = uimenu(figGraph, 'Label', 'Axes');
        
        % Create the axes limit adjustment menu option.
        uimenu(menuAaxes, ...
            'Callback', {@setaxeslimits}, ...
            'Label', 'Adjust limits', ...
            'Tag', 'menuItemAxesLimit');
        
        % Create the view (rotations) adjustment menu option.
        uimenu(menuAaxes, ...
            'Callback', {@setaxesview}, ...
            'Label', 'Adjust view', ...
            'Tag', 'menuItemAxesAngle');
        
        %% Axes adjustment functions
        function setaxeslimits(varargin)
            % SETAXESLIMITS Create a window to manually adjust axes limits
            %
            %
            
            %% Check for an existing limit adjustment figure.
            figLimits = getappdata(figGraph, 'figLimits');

            % If the adjustment window exists, raise it and return.
            if ~isempty(figLimits)
                figure(figLimits)
                return
            end

            %% Create the adjustment figure.
            % Get the parent figure position.
            figGraphPos = get(figGraph, 'Position');

            figLimitsWidth = 214;
            figLimitsHeight = 180;

            % Get the center of the parent.
            figLimitsPos = [...
                figGraphPos(1) + figGraphPos(3)/2 - figLimitsWidth/2
                figGraphPos(2) + figGraphPos(4)/2 - figLimitsHeight/2
                figLimitsWidth
                figLimitsHeight];

            % Create the figure.
            figLimits = figure(...
                'CloseRequestFcn', {@figlimitsclosereqfcn, figGraph}, ...
                'MenuBar', 'none', ...
                'Name', 'Limits', ...
                'NumberTitle', 'off', ...
                'Position', figLimitsPos, ...
                'Resize', 'off', ...
                'Tag', 'figLimits');

            %% Create the labels.
            uicontrol(...
                'Background', get(figLimits, 'Color'), ...
                'FontSize', 10, ...
                'Foreground', 'k', ...
                'HorizontalAlignment', 'Left', ...
                'Parent', figLimits, ...
                'Position', [10 116 50 24], ...
                'String', 'X Range', ...
                'Style', 'text', ...
                'Tag', 'textXRange')
        
            uicontrol(...
                'Background', get(figLimits, 'Color'), ...
                'FontSize', 10, ...
                'Foreground', 'k', ...
                'HorizontalAlignment', 'Left', ...
                'Parent', figLimits, ...
                'Position', [10 66 50 24], ...
                'String', 'Y Range', ...
                'Style', 'text', ...
                'Tag', 'textYRange')
        
            uicontrol(...
                'Background', get(figLimits, 'Color'), ...
                'FontSize', 10, ...
                'Foreground', 'k', ...
                'HorizontalAlignment', 'Left', ...
                'Parent', figLimits, ...
                'Position', [10 16 50 24], ...
                'String', 'Z Range', ...
                'Style', 'text', ...
                'Tag', 'textZRange')
        
            uicontrol(...
                'Background', get(figLimits, 'Color'), ...
                'FontSize', 10, ...
                'Foreground', 'k', ...
                'HorizontalAlignment', 'Center', ...
                'Parent', figLimits, ...
                'Position', [69 145 60 24], ...
                'String', 'Minimum', ...
                'Style', 'text', ...
                'Tag', 'textMinimum')
        
            uicontrol(...
                'Background', get(figLimits, 'Color'), ...
                'FontSize', 10, ...
                'Foreground', 'k', ...
                'HorizontalAlignment', 'Center', ...
                'Parent', figLimits, ...
                'Position', [144 145 60 24], ...
                'String', 'Maximum', ...
                'Style', 'text', ...
                'Tag', 'textMaximum')
        
            %% Create the adjustment edit boxes.
            % X adjustment boxes:
            xInitial = get(axesPlot, 'XLim');
            editXMin = uicontrol(...
                'Callback', @editxlimcallback, ...
                'KeyPressFcn', @editxminkeypresscallback, ...
                'Position', [75 120 48 24], ...
                'String', xInitial(1), ...
                'Style', 'edit', ...
                'Tag', 'editXMin', ...
                'TooltipString', 'Set the x axes range minimum');

            editXMax = uicontrol(...
                'Callback', @editxlimcallback, ...
                'KeyPressFcn', @editxmaxkeypresscallback, ...
                'Position', [150 120 48 24], ...
                'String', xInitial(2), ...
                'Style', 'edit', ...
                'Tag', 'editXMax', ...
                'TooltipString', 'Set the x axes range maximum');

            % Y adjustment boxes:
            yInitial = get(axesPlot, 'XLim');
            editYMin = uicontrol(...
                'Callback', @editylimcallback, ...
                'KeyPressFcn', @edityminkeypresscallback, ...
                'Position', [75 70 48 24], ...
                'String', yInitial(1), ...
                'Style', 'edit', ...
                'Tag', 'editYMin', ...
                'TooltipString', 'Set the y axes range minimum');

            editYMax = uicontrol(...
                'Callback', @editylimcallback, ...
                'KeyPressFcn', @editymaxkeypresscallback, ...
                'Position', [150 70 48 24], ...
                'String', yInitial(2), ...
                'Style', 'edit', ...
                'Tag', 'editYMax', ...
                'TooltipString', 'Set the y axes range maximum');

            % Z adjustment boxes:
            zInitial = get(axesPlot, 'ZLim');
            editZMin = uicontrol(...
                'Callback', @editzlimcallback, ...
                'KeyPressFcn', @editzminkeypresscallback, ...
                'Position', [75 20 48 24], ...
                'String', zInitial(1), ...
                'Style', 'edit', ...
                'Tag', 'editZMin', ...
                'TooltipString', 'Set the z axes range minimum');

            editZMax = uicontrol(...
                'Callback', @editzlimcallback, ...
                'KeyPressFcn', @editzmaxkeypresscallback, ...
                'Position', [150 20 48 24], ...
                'String', zInitial(2), ...
                'Style', 'edit', ...
                'Tag', 'zmaxedit', ...
                'TooltipString', 'Set the z axes range maximum');

            %% Store the adjustment figure's handle in the appdata of the main figure.
            setappdata(figGraph, 'figLimits', figLimits)

            %% Attach listeners to the axes to update the limits on a limit change.
            addlistener(axesPlot, 'XLim', 'PostSet', ...
                @(propLimit, eventData)limitsync(propLimit, eventData, editXMin, editXMax));
            addlistener(axesPlot, 'YLim', 'PostSet', ...
                @(propLimit, eventData)limitsync(propLimit, eventData, editYMin, editYMax));
            addlistener(axesPlot, 'ZLim', 'PostSet', ...
                @(propLimit, eventData)limitsync(propLimit, eventData, editZMin, editZMax));

            %% Nested functions for axes limit adjustments
            function editxlimcallback(varargin)
                % EDITXLIMCALLBACK Update the axes x limits
                %
                %
                
                %% Get the current x limits.
                currentXLim = get(axesPlot, 'XLim');

                %% Get the desired range.
                xMin = str2double(get(editXMin, 'String'));
                xMax = str2double(get(editXMax, 'String'));

                %% Test for a valid range, then update or reset.
                if xMin >= xMax
                    % Reset the x editbox values.
                    set(editXMin, 'String', currentXLim(1))
                    set(editXMax, 'String', currentXLim(2))

                else
                    % Update the axes range.
                    set(axesPlot, 'XLim', [xMin xMax])

                    % Update the xdata for the x axes center line.
                    set(xAx, 'XData', [xMin xMax])

                end % if
            end % editxlimcallback

            function editylimcallback(varargin)
                % EDITYLIMCALLBACK Update the axes y limits
                %
                %
                
                %% Get the current y limits.
                currentYLim = get(axesPlot, 'YLim');

                %% Get the desired range.
                yMin = str2double(get(editYMin, 'String'));
                yMax = str2double(get(editYMax, 'String'));

                %% Test for a valid range, then update or reset.
                if yMin >= yMax
                    % Reset the y editbox values.
                    set(editYMin, 'String', currentYLim(1))
                    set(editYMax, 'String', currentYLim(2))

                else
                    % Update the axes range.
                    set(axesPlot, 'YLim', [yMin yMax])

                    % Update the xdata for the x axes center line.
                    set(yAx, 'YData', [yMin yMax])

                end % if
            end % editylimcallback

            function editzlimcallback(varargin)
                % EDITZLIMCALLBACK Update the axes z limits
                %
                %
                
                %% Get the current z limits.
                currentZLim = get(axesPlot, 'ZLim');

                %% Get the desired range.
                zMin = str2double(get(editZMin, 'String'));
                zMax = str2double(get(editZMax, 'String'));

                %% Test for a valid range, then update or reset.
                if zMin >= zMax
                    % Reset the z editbox values.
                    set(editZMin, 'String', currentZLim(1))
                    set(editZMax, 'String', currentZLim(2))

                else
                    % Update the axes range.
                    set(axesPlot, 'ZLim', [zMin zMax])

                    % Update the xdata for the x axes center line.
                    set(zAx, 'ZData', [zMin zMax])

                end % if
            end % editzlimcallback

            function editxminkeypresscallback(varargin)
                % EDITXMINKEYPRESSCALLBACK Update the axes x min on up or down arrow
                %
                %
                
                %% Check for an up or down press.
                switch varargin{2}.Key

                    case 'uparrow'
                        xLim = get(axesPlot, 'XLim');
                        xLim(1) = xLim(1) + 1;
                        
                    case 'downarrow'
                        xLim = get(axesPlot, 'XLim');
                        xLim(1) = xLim(1) - 1;

                    otherwise
                        return
                
                end % switch
                
                %% Test for a valid range, and update the axes and editbox.
                if xLim(1) >= xLim(2)
                    return
                end % if

                set(editXMin, 'String', xLim(1))
                set(axesPlot, 'XLim', xLim)
            end % editzminkeypresscallback

            function editxmaxkeypresscallback(varargin)
                % EDITXMAXKEYPRESSCALLBACK Update the axes x max on up or down arrow
                %
                %
                
                %% Check for an up or down press.
                switch varargin{2}.Key

                    case 'uparrow'
                        xLim = get(axesPlot, 'XLim');
                        xLim(2) = xLim(2) + 1;

                    case 'downarrow'
                        xLim = get(axesPlot, 'XLim');
                        xLim(2) = xLim(2) - 1;

                    otherwise
                        return
                
                end % switch
                
                %% Test for a valid range, and update the axes and editbox.
                if xLim(1) >= xLim(2)
                    return
                end % if

                set(editXMax, 'String', xLim(2))
                set(axesPlot, 'XLim', xLim)
            end % editxmaxkeypresscallback

            function edityminkeypresscallback(varargin)
                % EDITYMINKEYPRESSCALLBACK Update the axes y min on up or down arrow
                %
                %
                
                %% Check for an up or down press.
                switch varargin{2}.Key

                    case 'uparrow'
                        yLim = get(axesPlot, 'YLim');
                        yLim(1) = yLim(1) + 1;

                    case 'downarrow'
                        yLim = get(axesPlot, 'YLim');
                        yLim(1) = yLim(1) - 1;

                    otherwise
                        return
                
                end % switch
                
                %% Test for a valid range, and update the axes and editbox.
                if yLim(1) >= yLim(2)
                    return
                end % if

                set(editYMin, 'String', yLim(1))
                set(axesPlot, 'YLim', yLim)
            end % editxminkeypresscallback

            function editymaxkeypresscallback(varargin)
                % EDITYMAXKEYPRESSCALLBACK Update the axes y max on up or down arrow
                %
                %
                
                %% Check for an up or down press.
                switch varargin{2}.Key

                    case 'uparrow'
                        yLim = get(axesPlot, 'YLim');
                        yLim(2) = yLim(2) + 1;

                    case 'downarrow'
                        yLim = get(axesPlot, 'YLim');
                        yLim(2) = yLim(2) - 1;

                    otherwise
                        return
                
                end % switch
                
                %% Test for a valid range, and update the axes and editbox.
                if yLim(1) >= yLim(2)
                    return
                end % if

                set(editYMax, 'String', yLim(2))
                set(axesPlot, 'YLim', yLim)
            end % editxmaxkeypresscallback

            function editzminkeypresscallback(varargin)
                % EDITZMINKEYPRESSCALLBACK Update the axes z min on up or down arrow
                %
                %
                
                %% Check for an up or down press.
                switch varargin{2}.Key

                    case 'uparrow'
                        zLim = get(axesPlot, 'ZLim');
                        zLim(1) = zLim(1) + 1;

                    case 'downarrow'
                        zLim = get(axesPlot, 'ZLim');
                        zLim(1) = zLim(1) - 1;

                    otherwise
                        return
                
                end % switch
                
                %% Test for a valid range, and update the axes and editbox.
                if zLim(1) >= zLim(2)
                    return
                end % if

                set(editZMin, 'String', zLim(1))
                set(axesPlot, 'ZLim', zLim)
            end % editzminkeypresscallback

            function editzmaxkeypresscallback(varargin)
                % EDITZMAXKEYPRESSCALLBACK Update the axes z max on up or down arrow
                %
                %
                
                %% Check for an up or down press.
                switch varargin{2}.Key

                    case 'uparrow'
                        zLim = get(axesPlot, 'ZLim');
                        zLim(2) = zLim(2) + 1;

                    case 'downarrow'
                        zLim = get(axesPlot, 'ZLim');
                        zLim(2) = zLim(2) - 1;

                    otherwise
                        return
                
                end % switch
                
                %% Test for a valid range, and update the axes and editbox.
                if zLim(1) >= zLim(2)
                    return
                end % if

                set(editZMax, 'String', zLim(2))
                set(axesPlot, 'ZLim', zLim)
            end % editzmaxkeypresscallback
        end % setaxeslimits

        function setaxesview(varargin)
            % SETAXESVIEW Create a window to manually adjust axes view
            %
            %

            %% Check for an existing view adjustment figure.
            figView = getappdata(figGraph, 'figView');

            % If the adjustment window exists, raise it and return.
            if ~isempty(figView)
                figure(figView)
                return
            end

            %% Create the view adjustment figure.
            % Set the size and position of the figure.
            parentPosition = get(figGraph, 'Position');

            figViewWidth = 152;
            figViewHeight = 83;
            figViewPos = [...
                parentPosition(1) + parentPosition(3)/2 - figViewWidth/2
                parentPosition(2) + parentPosition(4)/2 - figViewHeight/2
                figViewWidth
                figViewHeight];

            % Create the view adjustment figure.
            figView = figure(...
                'CloseRequestFcn', {@figviewclosereqfcn, figGraph}, ...
                'MenuBar', 'none', ...
                'Name', 'View', ...
                'NumberTitle', 'off', ...
                'Position', figViewPos, ...
                'Resize', 'off', ...
                'Tag', 'figView');

            %% Create the labels.
            uicontrol(...
                'Background', get(figView, 'Color'), ...
                'FontSize', 10, ...
                'Foreground', 'k', ...
                'HorizontalAlignment', 'Center', ...
                'Parent', figView, ...
                'Position', [10 45 60 24], ...
                'String', 'Azimuth', ...
                'Style', 'text', ...
                'Tag', 'textAzimuth')
        
            uicontrol(...
                'Background', get(figView, 'Color'), ...
                'FontSize', 10, ...
                'Foreground', 'k', ...
                'HorizontalAlignment', 'Center', ...
                'Parent', figView, ...
                'Position', [79 45 60 24], ...
                'String', 'Elevation', ...
                'Style', 'text', ...
                'Tag', 'textElevation')
            
            %% Create the view adjustment edit boxes.
            % Get the initial view.
            viewInitial = get(axesPlot, 'View');

            % Azimuth adjustment box:
            editAzimuth = uicontrol('Style', 'edit', ...
                'Callback', @editazimuthcallback, ...
                'KeyPressFcn', @editazimuthkeypresscallback, ...
                'Position', [16 20 48 24], ...
                'String', viewInitial(1), ...
                'Tag', 'editAzimuth', ...
                'TooltipString', 'Set the axes view aximuth (degrees)');

            % Elevation adjustment box:
            editElevation = uicontrol('Style', 'edit', ...
                'Callback', @editelevationcallback, ...
                'KeyPressFcn', @editelevationkeypresscallback, ...
                'Position', [85 20 48 24], ...
                'String', viewInitial(2), ...
                'Tag', 'editElevation', ...
                'TooltipString', 'Set the axes view elevation (degrees)');
            
            %% Store the adjustment figure's handle in the appdata of the main figure.
            setappdata(figGraph, 'figView', figView)

            %% Attach a listener to the axes to update the azimuth and elevation on a view change.
            addlistener(axesPlot, 'View', 'PostSet', ...
                @(propView, eventData)viewsync(propView, eventData, editAzimuth, editElevation));
            
            %% Nested functions for axes view adjustments
            function editazimuthcallback(varargin)
                % EDITAZIMUTHCALLBACK Update the axes azimuth
                %
                %
                
                %% Get the current axes x limits.
                currentView = get(axesPlot, 'View');

                %% Get the desired azimuth value.
                azValue = str2double(get(editAzimuth, 'String'));

                %% Test for a valid value, then update or reset.
                if ~isreal(azValue)
                    % Reset the azimuth editbox value.
                    set(editAzimuth, 'String', currentView(1))

                else
                    % Update the axes view.
                    set(axesPlot, 'View', [azValue currentView(2)])

                end % if
            end % editazimuthcallback

            function editelevationcallback(varargin)
                % EDITELEVATIONCALLBACK Update the axes elevation
                %
                %
                
                %% Get the current axes x limits.
                currentView = get(axesPlot, 'View');

                %% Get the elevation value.
                elValue = str2double(get(editElevation, 'String'));

                %% Test for a valid range, then update or reset.
                if ~isreal(elValue)
                    % Reset the elevation editbox value.
                    set(editElevation, 'String', currentView(2))

                else
                    % Update the axes view.
                    set(axesPlot, 'View', [currentView(1) elValue])

                end % if
            end % editelevationcallback

            function editazimuthkeypresscallback(varargin)
                % EDITAZIMUTHKEYPRESSCALLBACK Update the axes azimuth on up or down arrow
                %
                %
                
                %% Check for an up or down press.
                switch varargin{2}.Key

                    case 'uparrow'
                        viewValue = get(axesPlot, 'View');
                        viewValue(1) = viewValue(1) + 1;

                    case 'downarrow'
                        viewValue = get(axesPlot, 'View');
                        viewValue(1) = viewValue(1) - 1;

                    otherwise
                        return
                
                end % switch
                
                %% Update the editbox.
                set(editAzimuth, 'String', viewValue(1))
                set(axesPlot, 'View', viewValue)
            end % editazimuthkeypresscallback

            function editelevationkeypresscallback(varargin)
                % EDITELEVATIONKEYPRESSCALLBACK Update the axes elevation on up or down arrow
                %
                %
                
                %% Check for an up or down press.
                switch varargin{2}.Key

                    case 'uparrow'
                        viewValue = get(axesPlot, 'View');
                        viewValue(2) = viewValue(2) + 1;

                    case 'downarrow'
                        viewValue = get(axesPlot, 'View');
                        viewValue(2) = viewValue(2) - 1;

                    otherwise
                        return
                
                end % switch
                
                %% Update the editbox.
                set(editElevation, 'String', viewValue(2))
                set(axesPlot, 'View', viewValue)
            end % editelevationkeypresscallback
        end % setaxesview

        %% Sync functions for the adjustment figures
        function limitsync(propLimit, eventData, editMin, editMax)
            % VIEWSYNC Sync the limit window values with the axes limits
            %
            %

            if ishandle(editMin)
                %% Get the limits.
                limitValue = eventData.NewValue;

                %% Set the edit min and max boxes.
                set(editMin, 'String', limitValue(1))
                set(editMax, 'String', limitValue(2))
                
                %% Update the axis line.
                switch get(editMin, 'Tag')
                    
                    case 'editXMin'
                        set(xAx, 'XData', limitValue)
                        
                    case 'editYMin'
                        set(yAx, 'YData', limitValue)
                        
                    case 'editZMin'
                        set(zAx, 'ZData', limitValue)                        
                        
                end % switch
            end % if
        end % limitsync
        
        function viewsync(propView, eventData, editAzimuth, editElevation)
            % VIEWSYNC Sync the view window values with the axes view
            %
            %

            if ishandle(editAzimuth)
                %% Get the view.
                viewValue = eventData.NewValue;

                %% Set the azimuth and elevation edit boxes.
                set(editAzimuth, 'String', viewValue(1))
                set(editElevation, 'String', viewValue(2))
            end % if
        end % viewsync

        %% Close request functions
        function figgraphclosereqfcn(figGraph, eventData)
            % FIGGRAPHCLOSEREQFCN Closes the graph figure
            %
            %
            
            %% Check for associated axes adjustment figures.
            figLimits = getappdata(figGraph, 'figLimits');
            figView = getappdata(figGraph, 'figView');

            %% Delete any adjustment figures.
            if ~isempty(figLimits)
                delete(figLimits)
            end % if

            if ~isempty(figView)
                delete(figView)
            end % if

            %% Remove the figure's handle from base's graphChildren and delete the figure.
            graphChildren = getappdata(guiCenteredPlots, 'graphChildren');
            
            % Remove the current graph from the list.
            graphChildren(graphChildren == figGraph) = [];

            % Replace the appdata.
            setappdata(guiCenteredPlots, 'graphChildren', graphChildren)

            % Delete the figure.
            delete(figGraph)
        end % figgraphclosereqfcn

        function figlimitsclosereqfcn(figLimits, eventData, figGraph)
            % FIGLIMITSCLOSEREQFCN Closes the limits figure
            %
            %
            
            %% Remove the adjustment figure handle from the main figure's appdata.
            setappdata(figGraph, 'figLimits', [])

            %% Delete the limits adjustment figure.
            delete(figLimits)
        end % figlimitsclosereqfcn

        function figviewclosereqfcn(figView, eventData, figGraph)
            % FIGVIEWCLOSEREQFCN Closes the view figure
            %
            %
            
            %% Remove the adjustment figure handle from the main figure's appdata.
            setappdata(figGraph, 'figView', [])

            %% Delete the view adjustment figure.
            delete(figView)

        end % figviewclosereqfcn
    end % pushplotcallback
end % xtplottrackscommonorigin


function guiclosereqfcn(guiCenteredPlots, eventData)
    % GUICLOSEREQFCN Closes the GUI figure
    %
    %

        %% Delete any graph children and associated adjustment windows.
        graphChildren = getappdata(guiCenteredPlots, 'graphChildren');
        
        % Delete any adjustment figures associated with the graph.
        for c = 1:length(graphChildren)
            % Check for associated axes adjustment figures.
            figLimits = getappdata(graphChildren(c), 'figLimits');
            figView = getappdata(graphChildren(c), 'figView');

            % Delete any adjustment figures.
            if ~isempty(figLimits)
                delete(figLimits)
            end % if

            if ~isempty(figView)
                delete(figView)
            end % if
            
            delete(graphChildren(c))
        end % for c
        
        %% Delete the figure.
        delete(guiCenteredPlots)
end % guiclosereqfcn