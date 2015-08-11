clear
addpath(('3rd_party'));
% the sunPosition.m should be included to this code

% specify the start and end time
start_time  = '2015/01/01 05:00:00';
end_time    = '2015/12/31 05:00:00';
Interval_minutes = 30;

% CMU campus (40.443181, -79.943060)
% defaults to ULaval campus (46.779077, -71.275778)
location.latitude = 46.779077;
location.longitude = -71.275778;
location.altitude = 0;
UTC = -4;

% set to 15 for full moon
desiredLunarPhase = 1:30;

latitudes = 85:-5:-85;
%latitudes = location.latitude;

resultats_latitude = {};

idx_lat = 0;
for i_lat = latitudes
    idx_lat = idx_lat + 1;
    location.latitude = i_lat; % longitude controls the time in this code

    % Filter by Lunar Calendar
    %   we only watch the moon in full phase
    start_date = datestr(start_time,'yyyymmdd');
    end_date = datestr(end_time,'yyyymmdd');
    oneDayNum = datenum('02','dd') - datenum('01','dd');
    dayNb = (datenum(end_date,'yyyymmdd')-datenum(start_date,'yyyymmdd'))/oneDayNum;
    desiredDay = {}; lunarPhases = {};
    
    for i_d = 1:dayNb
        
        curDay = datestr(datenum(start_date,'yyyymmdd')+(i_d-1)*oneDayNum,'yyyymmdd');
        yyyy = curDay(1:4);mm=curDay(5:6);dd=curDay(7:8);
        lunarDay = LunarCalendar(yyyy,mm,dd); lunarDay = strsplit(lunarDay,':');lunarDay = lunarDay{3};    
        
        % Only select desired days
        lunarPhase = str2double(lunarDay(3:end));
        if ismember(lunarPhase, desiredLunarPhase)
            desiredDay{end + 1} = curDay;
            lunarPhases{end + 1} = lunarPhase;
        end
        
    end

    % Organize the date
    dateNumbers = length(desiredDay);
    timenumStep = Interval_minutes * (datenum('02','MM')-datenum('01','MM'));
    timenum24hour = 1;
    
    lambda_max = zeros(1, dateNumbers);

    % Compute the sun and moon position for each Full Moon Day
    for i_d = 1:dateNumbers
        curFullMoonDate = desiredDay{i_d};
        
        % Add time for this full moon day
        start_datetime = '08:00:00';
        start_datetime = strcat(curFullMoonDate,'-',start_datetime);
        start_datetimeNum = datenum( start_datetime,'yyyymmdd-HH:MM:SS');
        timeList = start_datetimeNum:timenumStep:(start_datetimeNum+timenum24hour+timenumStep);
        curDateTimeList = datestr(timeList,'yyyymmdd-HH:MM:SS');
        moon_cnt = 0; sun_cnt=0;
        
        for i_t = 1:length(curDateTimeList)
            curDateTime = curDateTimeList(i_t,:);
            curDateTimeNum = timeList(i_t);
            [year,m,d,h,mn,s] = datevec(curDateTimeNum);
            time = struct('year', year, 'month', m, 'day', d, ...
                     'hour', h, 'min', mn, 'sec', floor(s), 'UTC', UTC);

            angle = moonPosition(time,location);

            if angle.zenith > 0 
                moon_cnt = moon_cnt + 1;
                moon.position(moon_cnt,:) = [angle.azimuth,angle.zenith];
                [x,y,z] = sph2cart(angle.azimuth,pi/2-angle.zenith,1);
                moon.normal(moon_cnt,:) = column([x,y,z]);
                moon.time(moon_cnt,:) = time;
            end

            angle = sunPosition(time,location);

            if angle.zenith > 0
                sun_cnt = sun_cnt + 1;
                sun.position(sun_cnt,:) = [angle.azimuth,angle.zenith];
                [x,y,z] = sph2cart(angle.azimuth,pi/2-angle.zenith,1);
                sun.normal(sun_cnt,:) = column([x,y,z]);  
                sun.time(sun_cnt,:) = time;
            end
            
        end

        visibility_sun = sun.normal(:,3)>0;
        visibility_moon = moon.normal(:,3)>0;
        visibility_moon = visibility_moon & ~visibility_sun;

        [max_sunz,maxInd_sunz]= max(sun.normal(:,3));[min_sunz,minInd_sunz]= min(sun.normal(:,3));
        [max_sunx,maxInd_sunx]= max(sun.normal(:,1));[min_sunx,minInd_sunx]= min(sun.normal(:,1));

        [max_moonz,maxInd_moonz]= max(moon.normal(:,3));[min_moonz,minInd_moonz]= min(moon.normal(:,3));
        [max_moonx,maxInd_moonx]= max(moon.normal(:,1));[min_moonx,minInd_moonx]= min(moon.normal(:,1));
        
        % assert(maxInd_sunz==maxInd_sunx&minInd_sunz==minInd_sunx,'sun max min error');
        sun_plane = atan( (max_sunz-min_sunz)/(max_sunx-min_sunx))/pi*180;
        moon_plane = atan( (max_moonz-min_moonz)/(max_moonx-min_moonx))/pi*180;

        fig = figure('Position',[100 100 600 600],'Color','white');
        %% draw the result for this full moon day
        clf;
        fontsize = 14;
        % draw sun
        x = sun.normal(:,1); y = sun.normal(:,2); z = sun.normal(:,3);
        x = x(visibility_sun);y = y(visibility_sun);z = z(visibility_sun);
        plot3(x,y,z,'ro');  hold on;
        % draw moon
        x = moon.normal(:,1); y = moon.normal(:,2); z = moon.normal(:,3);
        x = x(visibility_moon);y = y(visibility_moon);z = z(visibility_moon);
        plot3(x,y,z,'b*');
        % draw sphere
        [x,y,z] = sphere(50);
        lightGrey = 0.8*[1 1 1]; % It looks better if the lines are lighter
        surface(x,y,z,'FaceColor', 'none','EdgeColor',lightGrey)
        % draw horizon
        plot3(x((z==0)),y((z==0)),z((z==0)),'black');
        
        % Add labels
        %xlabel('x');ylabel('y');zlabel('z')
        title(sprintf('sun moon position in %s location.lat:%02.f',curFullMoonDate,location.latitude),'FontSize',fontsize);
        text(0,-1.3,0,'east','fontsize',fontsize);text(0,1.3,0,'west','FontSize',fontsize)
        h=legend(sprintf('sun %02.f',[]),sprintf('full moon %02.f',[]),'Location','southeast');
        set(h,'Fontsize',fontsize);
        axis off equal
        
        if location.latitude >=0
            view(-70,25);
        else
            view(70,25);
        end

        %export_fig(sprintf('%s_lat%02.f.png',curFullMoonDate,location.latitude));
        close(fig);
        
        L = [sun.normal; moon.normal];
        lambda_max(i_d) = max(sqrt(svd(pinv(L'))));
    end
    fig = figure;
    cm = fliplr(parula(100));
    colormap(cm);
    colors = cm(round(0.5 * ( 1 + cos(abs(15 - cell2mat(lunarPhases))/15 * pi)) * 99 + 1),:);
    scatter(1:length(lambda_max), lambda_max, 1, colors);
    cb = colorbar;
    title(cb,'Moon illumination')
    hold on;
    for i = 1:length(lambda_max) - 1
        plot([i i+1], lambda_max(i:i+1), 'Color', colors(i,:));
    end
    hold off;
    xlabel('Day');
    ylabel('Maximum gain');
    %export_fig('maximum_gain.pdf', '-transparent')
    %export_fig('maximum_gain.png', '-transparent')
    close(fig);
    resultats_latitude{idx_lat} = lambda_max;
end